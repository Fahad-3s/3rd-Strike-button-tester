# 3rd-Strike-button-tester
A script that simulates attack interactions in Street Fighter III: 3rd Strike at every pixel distance, and writes at what timings it's a Win, a Loss or a Trade

## How to use:

Place `buttontester.lua` and `settings.ini` in the same folder.

Open settings.ini and go to lines 10 and 11, and then write the attacks you want to test after p1_buttons and p2_buttons, writing the name of the normal attack and if there are any directions being held during the attack, add them with numpad notation.

Numpad notation:

<img width="400" height="333" alt="image" src="https://github.com/user-attachments/assets/401b5cd4-2d08-48f8-8731-d22e6e436f41" />

So if you want the player to do "Down + MP", you write 2MP. If you want him to do MP without any direction, you write 5MP.

For example:

- p1_buttons = 5MP, 2MP
- p2_buttons = 2LP, 5MK, 6MK

With those settings, the script will simulate 5MP vs 2LP, 5MK and 6MK. Once it's done, it will simulate 2MP vs 2LP, 5MK, 6MK.

- The names of the attacks are: LP, MP, HP, LK, MK, HK.

If you want the characters to be crouched before the button press, set `p1_idle` and `p2_idle` to 2. Otherwise, leave it blank.

Once you have set it all up, open 3rd Strike on Fightcade and pick the two characters you want to test with. Place them at fullscreen distance away from each other, and just load the script. It will start testing the interactions, and once it's done, the results will be written to a folder with the name of the character.

Note: If `p1_idle` and `p2_idle` are set to 2, you should make the characters crouch before running the script.

And that's it. It's really hacky, but it works. Simulations tend to be quite slow, and the FBN emulator receives inputs from your controller/keyboard even when the window is minimized, so it's better to leave it running at times when you're not using your computer.
