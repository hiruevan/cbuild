var Module = {
  canvas: document.getElementById('canvas'),
  print: function (t) { console.log(t); },
  printErr: function (t) { console.error(t); },
  onExit: function (code) {
    window.close();
    // window.close() is ignored in most cases; fall back to a blank page
    setTimeout(function () { location.replace('about:blank'); }, 100);
  }
};

// Gamepads
window.addEventListener('gamepadconnected', function (e) {
  console.log('gamepad connected:', e.gamepad.id, 'mapping=' + e.gamepad.mapping);
});
window.addEventListener('gamepaddisconnected', function (e) {
  console.log('gamepad disconnected:', e.gamepad.id);
});