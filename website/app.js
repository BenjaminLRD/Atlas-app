// Atlas Landing Page Interactive Demo Controller

function switchDemoTab(tabName) {
  // Update nav buttons
  const buttons = document.querySelectorAll('.tab-btn');
  buttons.forEach(btn => btn.classList.remove('active'));

  // Find targeted button and set active
  const selectedBtn = Array.from(buttons).find(b =>
    b.getAttribute('onclick').includes(tabName)
  );
  if (selectedBtn) {
    selectedBtn.classList.add('active');
  }

  // Update tab panes
  const panes = document.querySelectorAll('.tab-pane');
  panes.forEach(pane => pane.classList.remove('active'));

  const targetPane = document.getElementById(`tab-${tabName}`);
  if (targetPane) {
    targetPane.classList.add('active');
  }
}

// Auto-rotate demo tabs on interval if user is not actively clicking
let currentTabIndex = 0;
const tabs = ['athlete', 'workouts', 'nutrition', 'ai-coach'];
let isUserInteracting = false;

document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    isUserInteracting = true;
  });
});

setInterval(() => {
  if (!isUserInteracting) {
    currentTabIndex = (currentTabIndex + 1) % tabs.length;
    switchDemoTab(tabs[currentTabIndex]);
  }
}, 5000);
