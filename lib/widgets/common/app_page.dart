import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'ambient_background.dart';
import 'app_header.dart';

/// Unified Page Scaffold Container component (`AppPage`).
class AppPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final bool showHeader;
  final bool showNotifications;
  final bool showSettings;
  final bool isBackPage;
  final VoidCallback? onBackTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;
  final Widget? headerTrailing;
  final EdgeInsetsGeometry? padding;

  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.showHeader = true,
    this.showNotifications = true,
    this.showSettings = true,
    this.isBackPage = false,
    this.onBackTap,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.headerTrailing,
    this.padding,
  });

  const AppPage.back({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.onBackTap,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.headerTrailing,
    this.padding,
  }) : showHeader = true,
       showNotifications = false,
       showSettings = false,
       isBackPage = true;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: showHeader
          ? (isBackPage
                ? AppHeader.back(
                    title: title,
                    subtitle: subtitle,
                    onBackTap: onBackTap,
                    trailing: headerTrailing,
                  )
                : AppHeader.standard(
                    title: title,
                    subtitle: subtitle,
                    showNotifications: showNotifications,
                    showSettings: showSettings,
                    onNotificationsTap: onNotificationsTap,
                    onSettingsTap: onSettingsTap,
                  ))
          : null,
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding:
              padding ??
              EdgeInsets.only(
                top: showHeader ? 12 : topInset + 16,
                bottom: bottomInset + 130,
                left: 16,
                right: 16,
              ),
          child: body,
        ),
      ),
    );
  }
}
