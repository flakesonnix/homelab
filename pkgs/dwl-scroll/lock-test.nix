# Test-only Wayland client; it only receives the smoke test's private socket.
{ pkgs }:
pkgs.runCommandCC "dwl-scroll-test-locker"
  {
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.wayland-scanner
    ];
    buildInputs = [ pkgs.wayland ];
  }
  ''
    protocol=${pkgs.wayland-protocols}/share/wayland-protocols/staging/ext-session-lock/ext-session-lock-v1.xml
    wayland-scanner client-header "$protocol" ext-session-lock-v1-client-protocol.h
    wayland-scanner private-code "$protocol" ext-session-lock-v1-client-protocol.c
    mkdir -p "$out/bin"
    $CC -std=c11 -Wall -Wextra -Werror -I. ${./lock-test.c} \
      ext-session-lock-v1-client-protocol.c $(pkg-config --cflags --libs wayland-client) \
      -o "$out/bin/dwl-scroll-test-locker"
  ''
