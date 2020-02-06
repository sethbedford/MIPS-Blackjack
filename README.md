# MIPS-Blackjack
Created November, 2018. Very basic singe-player blackjack game written in MIPS that uses a bitmap display.

# Usage
* Open with MARS (https://courses.missouristate.edu/KenVollmar/MARS/)
* Configure Bitmap Display
  * Select Tools > Bitmap Display
  * Set Unit Width and Height to 4
  * Set Display Width and Height to 512
  * Set Base address to 0x10040000 (heap)
  * Click "Connecto to MIPS" at bottom left of the window
* Run the program 
  * Assembly the program (F3)
  * Run the program (F5)

# Rules
This game follows the standard rules for blackjack. A few notes:
* This game is played with a five-card Charlie
* Splitting is not supported
* The dealer stands on soft 17s
