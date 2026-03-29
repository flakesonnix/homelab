{ lib
, stdenvNoCC
, win2xcur
, makeDesktopItem
}:

stdenvNoCC.mkDerivation {
  pname = "hello-kitty-peach-milk-donut-cursors";
  version = "1.0";

  src = ./hello-kitty-peach-milk-donut;

  nativeBuildInputs = [ win2xcur makeDesktopItem ];

  buildPhase = ''
    mkdir -p $out/share/icons/HelloKittyPeachMilkDonut/cursors

    # Convert each .cur file to xcursor
    win2xcur --output-dir $out/share/icons/HelloKittyPeachMilkDonut/cursors Hello_Normal.cur default
    win2xcur --output-dir $out/share/icons/HelloKittyPeachMilkDonut/cursors Hello_Link.cur pointer
    win2xcur --output-dir $out/share/icons/HelloKittyPeachMilkDonut/cursors Hello_Text.cur text
    win2xcur --output-dir $out/share/icons/HelloKittyPeachMilkDonut/cursors Hello_Busy.cur wait
    win2xcur --output-dir $out/share/icons/HelloKittyPeachMilkDonut/cursors Hello_Background.cur all-scroll
    win2xcur --output-dir $out/share/icons/HelloKittyPeachMilkDonut/cursors Hello_Unavailable.cur not-allowed

    # Create additional symlinks for X11 cursor compatibility
    cd $out/share/icons/HelloKittyPeachMilkDonut/cursors

    # default variants
    ln -sf default left_ptr
    ln -sf default arrow
    ln -sf default center_ptr
    ln -sf default top_left_arrow
    ln -sf default top_left_corner
    ln -sf default top_side
    ln -sf default top_right_corner
    ln -sf default right_side
    ln -sf default bottom_right_corner
    ln -sf default bottom_side
    ln -sf default bottom_left_corner
    ln -sf default left_side
    ln -sf default cross
    ln -sf default crosshair
    ln -sf default dnd-ask
    ln -sf default dnd-copy
    ln -sf default dnd-link
    ln -sf default dnd-move
    ln -sf default dnd-none

    # pointer variants
    ln -sf pointer hand1
    ln -sf pointer hand2
    ln -sf pointer pointing_hand
    ln -sf pointer e292e34e6344162e8bdde3dd3bc7e1f8

    # text variants
    ln -sf text xterm
    ln -sf text ibeam
    ln -sf text vertical-text

    # wait variants
    ln -sf wait watch
    ln -sf wait progress
    ln -sf wait half-busy
    ln -sf wait 08e8e1c95fe7076c5c3d1b89d5ad7e41
    ln -sf wait 3ec5d0d6f76b4b1e9b0e0f0c3d9f000

    # all-scroll variants
    ln -sf all-scroll move
    ln -sf all-scroll fleur
    ln -sf all-scroll 08e8e1c95fe7076c5c3d1b89d5ad7e41

    # not-allowed variants
    ln -sf not-allowed crossed_circle
    ln -sf not-allowed forbidden
    ln -sf not-allowed 05ac1e8138d3c7a4d6c5e0c2c0c0d0f

    # Create cursor.theme
    cat > $out/share/icons/HelloKittyPeachMilkDonut/cursor.theme << EOF
[Icon Theme]
Name=HelloKittyPeachMilkDonut
Comment=Hello Kitty Peach Milk Donut Cursor Theme
Inherits=Adwaita
EOF

    # Create index.theme for XDG
    cat > $out/share/icons/HelloKittyPeachMilkDonut/index.theme << EOF
[Icon Theme]
Name=HelloKittyPeachMilkDonut
Comment=Hello Kitty Peach Milk Donut Cursor Theme
Inherits=Adwaita
Directories=cursors

[cursors]
Size=32
Context=Animations
EOF

    # Copy preview image
    cp ../Hello_Cursor\ Set.png $out/share/icons/HelloKittyPeachMilkDonut/cursor-preview.png
  '';

  installPhase = ''
    mkdir -p $out
  '';

  outputs = [ "out" ];
}
