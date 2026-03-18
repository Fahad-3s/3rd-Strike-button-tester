# 3rd-Strike-button-tester
A script that simulates attack interactions in Street Fighter III: 3rd Strike at every pixel distance, and writes at what timings it's a Win, a Loss or a Trade

How to use:

Open settings.ini and go to lines 10 and 11, and then write the attacks you want to test after p1_buttons and p2_buttons, writing the name of the normal attack and if there are any directions being held during the attack, add them with numpad notation.

Numpad notation:

<img width="400" height="333" alt="image" src="https://github.com/user-attachments/assets/401b5cd4-2d08-48f8-8731-d22e6e436f41" />

So if you want the player to do "Down + MP", you write 2MP. If you want him to do MP without any direction, you write 5MP.

For example:

p1_buttons = 5MP, 2MP
p2_buttons = 2LP, 5MK, 6MK

With those settings, the script will simulate 5MP vs 2LP, 5MK and 6MK. Once it's done, it will simulate 2MP vs 2LP, 5MK, 6MK.

The names of the attacks are: LP, MP, HP, LK, MK, HK.
