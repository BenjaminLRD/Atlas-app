// Opt-in check of the real Community flow against a real Supabase project.
//
// It is skipped unless every value below is supplied, so `flutter test` never
// touches a backend. It uses the public anon key and two ordinary TEST
// accounts' passwords; it never uses a service-role key and cannot bypass
// row-level security. It creates one post as account A and deletes it again.
//
//   flutter test test/live/cardio_community_live_test.dart \
//     --dart-define=LIVE_SUPABASE_URL=https://<project>.supabase.co \
//     --dart-define=LIVE_SUPABASE_ANON_KEY=<anon key> \
//     --dart-define=LIVE_USER_A_EMAIL=... --dart-define=LIVE_USER_A_PASSWORD=... \
//     --dart-define=LIVE_USER_B_EMAIL=... --dart-define=LIVE_USER_B_PASSWORD=...
//
// Use throw-away accounts on a staging project. This file has NOT been run
// against a backend by the author of the feature.
import 'dart:math' as math;

import 'package:atlas/models/cardio_activity_data.dart';
import 'package:atlas/models/cardio_route.dart';
import 'package:atlas/services/cardio/route_privacy.dart';
import 'package:atlas/services/community/cardio_post_publisher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('LIVE_SUPABASE_URL');
const _anon = String.fromEnvironment('LIVE_SUPABASE_ANON_KEY');
const _aMail = String.fromEnvironment('LIVE_USER_A_EMAIL');
const _aPass = String.fromEnvironment('LIVE_USER_A_PASSWORD');
const _bMail = String.fromEnvironment('LIVE_USER_B_EMAIL');
const _bPass = String.fromEnvironment('LIVE_USER_B_PASSWORD');

bool get _configured =>
    [_url, _anon, _aMail, _aPass, _bMail, _bPass].every((v) => v.isNotEmpty);

void main() {
  test(
    'publish, view, like, comment and isolate a cardio post (REAL backend)',
    () async {
      final a = SupabaseClient(_url, _anon);
      final b = SupabaseClient(_url, _anon);
      await a.auth.signInWithPassword(email: _aMail, password: _aPass);
      await b.auth.signInWithPassword(email: _bMail, password: _bPass);
      final aId = a.auth.currentUser!.id;
      final bId = b.auth.currentUser!.id;
      expect(aId, isNot(bId));

      const lat0 = 23.7271;
      const lng0 = 92.7176;
      final route = [
        for (var i = 0; i <= 200; i++)
          RoutePoint(lat0 + i * 10 / 111195, lng0, i * 1000),
        for (var i = 200; i >= 0; i--)
          RoutePoint(lat0 + i * 10 / 111195, lng0 + 0.0003, 0),
      ];
      final activity = CardioActivityData(
        kind: CardioKind.running,
        title: 'Outdoor Run',
        date: DateTime.now(),
        distanceKm: 4.02,
        durationSeconds: 1500,
        avgSpeedKmh: 9.65,
        calories: 300,
        route: route,
      );
      final draft = CardioPostPublisher.buildDraft(
        activity,
        caption: 'live test ${DateTime.now().millisecondsSinceEpoch}',
        privacy: RoutePrivacyMode.hide200,
      );

      // 1 and 2: A publishes with a caption.
      final inserted = await a
          .from('community_posts')
          .insert({
            'user_id': aId,
            'type': draft.type.name,
            'title': draft.title,
            'description': draft.description,
            'images': <String>[],
            'metadata': draft.metadata ?? const {},
          })
          .select()
          .single();
      final postId = inserted['id'] as String;
      try {
        // 3: metadata and route were saved as sent, masked.
        final m = Map<String, dynamic>.from(inserted['metadata'] as Map);
        expect(m['activity'], 'running');
        expect(m['distanceKm'], 4.02);
        final stored = RoutePoint.listFromJson(m['route']);
        expect(stored, isNotEmpty);
        final home = route.first;
        final closest = stored
            .map((p) => Geo.distanceM(home.lat, home.lng, p.lat, p.lng))
            .reduce(math.min);
        expect(closest, greaterThanOrEqualTo(199));

        // 4 to 7: B sees it, with the same route, and can like and comment.
        final seen = await b
            .from('community_posts')
            .select()
            .eq('id', postId)
            .single();
        expect(seen['type'], 'cardio');
        expect(seen['metadata']['route'], m['route']);
        await b.from('community_likes').insert({
          'post_id': postId,
          'user_id': bId,
        });
        await b.from('community_comments').insert({
          'post_id': postId,
          'user_id': bId,
          'body': 'live test comment',
        });
        final likes = await a
            .from('community_likes')
            .select()
            .eq('post_id', postId);
        expect(likes.length, 1);

        // B must not be able to post as A, edit, or delete A's post.
        await expectLater(
          b.from('community_posts').insert({
            'user_id': aId,
            'type': 'cardio',
            'title': 'forged',
          }),
          throwsA(isA<PostgrestException>()),
        );
        final deniedDelete = await b
            .from('community_posts')
            .delete()
            .eq('id', postId)
            .select();
        expect(deniedDelete, isEmpty);
      } finally {
        await a.from('community_posts').delete().eq('id', postId);
      }

      // 8: a sample id is not a server id, so it can never be a row.
      await a.auth.signOut();
      await b.auth.signOut();
    },
    skip: _configured
        ? false
        : 'Set the LIVE_* dart-defines to run against a real backend.',
  );
}
