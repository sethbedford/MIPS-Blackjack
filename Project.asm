# Seth Bedford
# Check external docs for Bitmap Display settings
# Only functions which take arguments have been blocked out entirely -- other functions are separated by line breaks
	.data

	# memory allocation for variables used throughout the program
dealerY:	.word	5
playerY:	.word	87
cardWidth:	.word	20
cardHeight:	.word	28
cardColor:	.word   0xffffff
balance:	.word   100
wagerVal:	.word 	0
pCards:		.word	0
dCards:		.word	0
pVals:		.space	24
dVals:		.space	24
wager:		.asciiz "Please enter the amount you would like to wager: \n (Note: This table has a $10 minimum. All players start with $100. To see your current balance, press Cancel)"
wagererr:	.asciiz "Your wager was invalid. It must be an integer lower than your current balance and higher than the table minimum. \n Please enter a wager. You may press Cancel to see your current balance"
balmsg:		.asciiz "Your current balance is: "
options:	.asciiz "Click the button that corresponds to your desired move: \n Yes: Hit \n No: Stand \n Cancel: Double Down (Only on first move -- acts as 'No' all other times)"
lostHand:	.asciiz "You lost that hand. Better luck next time. Would you like to continue playing? \n (Your balance will be preserved)"
wonHand:	.asciiz "You won that hand. Your balance has been updated. Would you like to continue playing? \n (Your balance will be preserved)"
tieHand:	.asciiz "This hand was a draw. Your wager has been refunded. Would you like to continue playing? \n (Your balance will be preserved)"
endGame:	.asciiz "Your balance is not high enough to meet the minimum balance. Game Over."

	.text
main:
	li $t0, 0		# reset these variables for when the game is rerun
	sw $t0, pCards
	sw $t0, dCards

	li $t0, 0x0f7141 # board bg color
	li $t1, 128 # dimension of board
	mul $t1, $t1, $t1 # area of board
	mul $t1, $t1, 4 # final address of board
	add $t1, $t1, 0x10040000 # add heap offset for starting point
	addi $t2, $zero, 0x10040000 # loop 
backg:	beq $t2, $t1, main2
	sw $t0, 0($t2) # color pixel
	addi $t2, $t2, 4 # increment one byte
	j backg

main2:
	
	li $a3, 1
	jal drawHidden # draw the "deck" that is placed center screen
	
wage:	la $a0, wager # prompt the user for their wager amount
	li $v0, 51
	syscall
	
wage2:	beq $a1, 0, action	# user entered syntactically-valid input -- check logical validity
	beq $a1, -2, showBalance	# user wants to see balance -- show balance
	
werr:	la $a0, wagererr	# the user's input was syntactically invalid -- prompt again
	li $v0, 51
	syscall
	
	j wage2		# loop until a valid wager is made
showBalance:		# function to show the user's current balance
	la $a0, balmsg	# display a message along with the user's balance
	lw $a1, balance
	li $v0, 56
	syscall
	
	j wage		# reprompt for player's wager amount

action:	blt $a0, 10, werr	# player's wager amount is less than 10 -- display an error and reprompt
	lw $t0, balance		# check if player's wager amount is under their balance
	bgt $a0, $t0, werr	# if not, display an error and reprompt
	sw $a0, wagerVal	# if so, store wager amount 
	lw $t1, wagerVal
	sub $t1, $t0, $t1
	sw $t1, balance		# reduce balance by wager amount

deal:   li $t9, 1		# deal the four initial cards after user has made their wager
	jal dealCard		
	li $t9, 0
	jal dealCard
	li $t9, 1
	jal dealCard
	li $a3, 0
	jal drawHidden		# this card is the hidden card on the dealer's side
	li $a0, 1
	jal handValue		# check if the player was dealt a blackjack
	beq $a2, 21, pbj	# skip user action if they were
	syscall
	
userprompt:
	lw $t3, pCards		# load player card count
	beq $t3, 5, stand	# if player has 5 cards dealt, instantly stand
	la $a0, options		# display the player's options and wait for input
	li $v0, 50
	syscall
	
	beq $a0, 0, hit		# user clicks YES --> hit
	beq $a0, 1, stand	# user clicks NO --> stand
	beq $a0, 2, double	# user clicks CANCEL --> double down
hit:	li $t9, 1
	jal dealCard		# deal a card to the player
	li $a0, 1	
	jal handValue		# check value of the player's hand
	beq $a2, 0, gameOver	# if the player exceeded 21, the round is lost
	j userprompt		# otherwise, continue prompting
stand:	beq $t3, 5, handWin	# if standing with 5 cards after validating the hand, user wins by charlie rule
	li $t7, 0		# flag for blackjack
	j dealerPlay		# after standing, it's time for the dealer to play
double: lw $t3, pCards		
	bne $t3, 2, hit		# if this turn is any turn other than the first, run the hit command
	lw $t0, balance		
	lw $t1, wagerVal
	blt $t0, $t1, hit	# if the remaining balance is lower than the wager amount, run the hit command
	sub $t0, $t0, $t1	
	sw $t0, balance		# update the new balance if double down comand is valid
	add $t1, $t1, $t1
	sw $t1, wagerVal	# update wager amount to twice its original value
	li $t9, 1
	jal dealCard		# deal a new card to the player
	li $a0, 1
	jal handValue		# get hand value
	beq $a2, 0, gameOver	# game over if hand value exceeds 21
	j dealerPlay		# move on to dealer play if game is not over
	
	
pbj:	li $t7, 1		# player got a blackjack, set flag


dealerPlay:
ddeal:	li $t9, 0		
	lw $t8, dCards
	jal dealCard		# deal a card to the dealer
	li $a0, 0
	jal handValue		# check the hand value
	beq $a2, 0, handWin	# if the dealer exceeded 21, the player wins
	beq $t8, 4, gameOver 	# dealer has drawn 5 cards without reaching 21, player loses
	blt $a2, 17, ddeal	# dealer has yet to draw 5 cards or exceed 17, so continue drawing cards
	
	addi $s5, $a2, 0
	li $a0, 1
	jal handValue		# check dealer hand value
	li $t6, 0
	bne $t8, 2, nbj		# dealer might have blackjack
	bne $s5, 21, nbj	# dealer does have blackjack
	li $t6, 1		# set dealer blackjack flag
nbj:	bne $t7, 1, nbjt	# player has blackjac
	bne $t6, 1, nbjt	# dealer has blackjack
	j tie			# two blackjacks tie
nbjt:	bne $t7, 1, npbj	# player has blackjack but dealer doesn't
	j handWin		# player wins
npbj:	bne $t6, 1, nbjw	# dealer has blackjack but player doesn't
	j gameOver		# dealer wins
nbjw:	bgt $a2, $s5, handWin	# neither player has blackjack and the player's hand is valued higher than the dealer's --> player wins
	blt $a2, $s5, gameOver	# neither player has blackjack and the dealer's hand is valued higher than the player's --> dealer wins
	j tie			# both players have the same valued hand --> tie
	j Exit

handWin:			# player wins
	lw $t0, wagerVal
	lw $t1, balance
	add $t1, $t1, $t0
	add $t1, $t1, $t0
	sw $t1, balance		# increase balance by wager x 2 
	la $a0, wonHand		# output winning message
	li $v0, 50
	syscall
	
	bne $a0, 0, Exit	# exit if the player is done playing
	j main			# reset the board if the player decides to keep playing
	
gameOver: 			# player loses
	la $a0, lostHand	# output loss message
	li $v0, 50
	syscall
	
	bne $a0, 0, Exit	# exit if the player decides to stop playing
	lw $t0, balance		# check if player has a valid balance to continue playing
	blt $t0, 10, end	# end game if he does not
	j main			# if he does, reset game 
end:	la $a0, endGame		# insufficient funds message
	li $a1, 0
	li $v0, 55
	syscall
	j Exit			# game ends
tie:	lw $t0, wagerVal	# tie game
	lw $t1, balance	
	add $t1, $t1, $t0
	sw $t1, balance		# refund the player's wager
	
	la $a0, tieHand		# output tie message
	li $v0, 50
	syscall
	
	bne $a0, 0, Exit
	j main
	
#------------------------
# checks value of player's or dealer's hand. set $a0 to player id (1 = player, 0 = dealer). returns $a2 = hand value (0 if bust)
#------------------------
handValue:
	li $s0, 0 	# flag for aces
	la $t0, dVals		# array containing cards for dealer
	lw $t2, dCards
	beq $a0, 0, hand2	# evaluate dealer hand
	la $t0, pVals		# array containing cards for player
	lw $t2, pCards		# evaluate player hand
hand2:	li $t1, 0		# iterator
	li $t4, 0		# hand value
hand1:	lw $t3, 0($t0)		# current card value from player/dealer's hand
	bgt $t3, 10, faceV	# check if card is face card
	add $t4, $t4, $t3	# if not, add value to the total
	bne $t3, 1, nFaceV	# check if card is an ace
	addi $s0, $s0, 1	# if so, set ace flag
	j nFaceV		
faceV:	addi $t4, $t4, 10	# card is a face card, only add 10 to the value
nFaceV:	addi $t1, $t1, 1	# increase iterator
	addi $t0, $t0, 4	# go to next card value
	blt $t1, $t2, hand1	# iterate until all cards are totaled up
	
	addi $a2, $t4, 0	# move total value to $a2
	ble $a2, 21, nBust	# check if hand is bust
	li $a2, 0		# set a2 to 0 if it is
	j hande
nBust:	beq $s0, 0, hande	# check if hand contains ace
	addi $s0, $a2, 10	# see if adding 10 makes handbetter
	bgt $s0, 21, hande	# if not, use old hand
	la $a2, ($s0)		# if so, update hand value
	
hande:	jr $ra
	

#------------------------
# deals cards to players. set $t9 to player id (1 = player, 0 = dealer)
#------------------------
dealCard:
	li $v0, 30		# seed RNG with time
	syscall
	
	li $v0, 42		# generate random number for suit (0 - 3)
	li $a1, 4
	syscall
	
	addi $a0, $a0, 1	# increase number by one so range is now 1 - 4
	la $a2, ($a0)		# store suit in appropriate var
	
	li $v0, 30		# seed RNG
	syscall
	
	li $v0, 42		# generate random number for card value (0 - 12)
	li $a1, 13
	syscall
	
	addi $a0, $a0, 1	# increase value by one so new range is 1 - 13
	la $a3, ($a0)		# store value in appropriate var
	
	li $v0, 30
	syscall
	
	beq $t9, 0, dealer	# check if dealing to dealer
	lw $a0, pCards		# otherwise, deal to player
	lw $a1, playerY
	la $t0, pVals
	addi $t9, $a0, 1
	sw $t9, pCards		# increase player card count by one
	j player
dealer:	lw $a0, dCards		# deal to dealer
	lw $a1, dealerY
	la $t0, dVals
	addi $t9, $a0, 1
	sw $t9, dCards		# increase dealer card count by one
player:	li $t1, 4
	mul $t2 $a0, $t1	# calculate end of card array
	add $t0, $t0, $t2	# move array pointer to end
	sw $a3, 0($t0)		# store new card value at end of array
	addi $sp, $sp, -4	# store the return address onto the stack for nested functions
	sw $ra, 0($sp)
	jal drawCard_init	# draw the generated card
	lw $ra, 0($sp)
	addi $sp, $sp, 4	# retrieve return address
	jr $ra			# return to caller

#-------------------------
# used to draw the hidden card from the dealer -- set $a3 to 1 to draw the deck
#-------------------------
drawHidden: 
	li $a0, 4
	li $a1, 46		# set custom y value for deck -- middle of board
	li $a2, -2		# set flag so that the function knows to draw a hidden card
	beq $a3, 1, drDeck	# if a3 is not set to 1, draw the hidden card for the dealer instead
	li $a0, 1
	li $a1, 5
drDeck:	j drawCard_init		# call drawCard function
hid1:	jr $ra			# return to caller
#-------------------------
# $a0 contains card number, $a1 contains dealer or player, $a2 contains suit, $a3 contains value
#-------------------------
drawCard_init:
	li $t9, 0
	add $t9, $t9, $a0
drawCard:
	li $t0, 128 	# Store screen width into $t0
	mul $t0, $t0, $a1	# multiply by y position
	li $t7, 20		# card width
	li $t8, 28		# card height
	mul $t1, $a0, $t7	# card X offset
	li $s0, 5		# distance between cards
	lw $s1, pCards		# number of cards player has
	addi $s1, $s1, -1	# subtract that number by one so the offset is correct
	bne $s1, 0, pCont	# first card . . . 
	bne $a1, 87, pCont	# for the dealer . . . 
	addi $t0, $t0, 5	# gets a 5 pixel corrective offset
pCont:	beq $a1, 87, pCO	# if drawing a dealer card, overwrite previously-set values to dealer-equivalent
	lw $s1, dCards		
	bne $s1, 1, dCO
	addi $t0, $t0, 5
dCO:	addi $s1, $s1, -1
pCO:	mul $s1, $s1, $s0	# calculate card margin offset depending on location
	add $t0, $t0, $s1	# add it to drawing pointer
	add $t0, $t0, $t1	# add card width offset
	mul $t0, $t0, 4		# multiply by 4 to get byte value
	add $t0, $t0, 0x10040000	# add heap pointer from bitmap display
	beq $t9, 0, firstCard	# add 5 pixels if this is not the first card
	addi $t0, $t0, 20
firstCard:
	beq $a0, -1, nums	# flag that signals base card is done being drawn -- continue to draw the nums
	beq $a0, -2, suits	# flag that signals base card and nums are done -- continue to draw the suits

	li $t1, 0		# iterator counters
dc2:	li $t2, 0
dc3:	li $t3, 0xffffff	# base color
	bne $t1, 0, dc5		# skip the corners of the card
	beq $t2, 0, skip
	beq $t2, 19, skip
	j dc8
dc5:	bne $t1, 27, dc8
	beq $t2, 0, skip
	beq $t2, 19 skip
dc8:	bne $a2, -2, white	# if this is not a hidden card, skip the below code
	add $t4, $t2, $t1	# add the column and row number and divide by 2
	li $t5, 2		# this allows the colors to alternate in a checkerboard pattern
	div $t4, $t5
	mfhi $t4
	beq $t1, 0, red2	# color the border red
	beq $t1, 27, red2
	beq $t2, 0, red2
	beq $t2, 19, red2
	beq $t4, 0, white	# color the current pixel white if it's in an even square
red2:	li $t3, 0xe71b24	# color it red if it's in an odd square
white:	sw $t3, 0($t0)		# color the pixel
skip:	addi $t0, $t0, 4	# go to next pixel
	addi $t2, $t2, 1	# increase column counter
	slt $t4, $t2, $t7	
	beq $t4, 1, dc3		# keep going for the entire width of the card
	addi $t1, $t1, 1	# increase row counter
	slt $t4, $t1, $t8
	li $t5, 108		# next row
	li $t6, 4
	mul $t5, $t5, $t6	# calculate bytes to next row
	add $t0, $t0, $t5	# increase pointer to next row starting point
	beq $t4, 1, dc2		# keep going for the entire height of the card
	
	beq $a2, -2, hid1
	li $a0, -1 # flag for finished drawing base card
	j drawCard

#------------------------------
# the belwow function draws the numbers for the cards. comments have been provided for only the first number
#------------------------------	
	
nums:
	addi $t0, $t0, 1112 	# offset for top left number
	mul $t4, $t9, $t7	# increase offset to number square
	li $t5, 4
	mul $t4, $t4, $t5
	add $t0, $t0, $t4
	li $t3, 0xe71b24	# set red color
	bgt $a2, 2, red		# use red if suit is 3 or 4
	li $t3, 0x000000	# if not using red, overwrite with black
red:	li $t1, 0		# iterators for row and column
nums2:	li $t2, 0
nums3:  beq $a3, 1, n1		# the below conditional branches determine which number will be drawn based on the number card selected
	beq $a3, 2, n2
	beq $a3, 3, n3
	beq $a3, 4, n4
	beq $a3, 5, n5
	beq $a3, 6, n6
	beq $a3, 7, n7
	beq $a3, 8, n8
	beq $a3, 9, n9
	beq $a3, 10, n10
	beq $a3, 11, n11
	beq $a3, 12, n12
	beq $a3, 13, n13
n1:	bne $t1, 0, n1a		# when drawing a number, select which rows and columns will contain colored pixels -- this is row 0
	bne $t2, 1, n1a		# col 1
	sw $t3, 0($t0)		# color it (this is the dot on top of the A)
n1a:	bne $t2, 0, n1b		# column 0
	blt $t1, 1, n1b		# rows greater than 0
	sw $t3, 0($t0)		# color (this is the left line of A)
n1b:	bne $t2, 2, n1c		# column 2
	blt $t1, 1, n1c		# row 1
	sw $t3, 0($t0)		# color it (this is the right line of A)
n1c:	bne $t1, 2, nend		# --------------> Repeat the above steps for each number, changing which pixels get colored accordingly
	bne $t2, 1, nend
	sw $t3, 0($t0)
	j nend
n2:	bne $t1, 0, n2a
	sw $t3, 0($t0)
n2a:	bne $t1, 1, n2b
	bne $t2, 2, n2b
	sw $t3, 0($t0)
n2b:	bne $t1, 2, n2c
	sw $t3, 0($t0)
n2c:	bne $t1, 3, n2d
	bne $t2, 0, n2d
	sw $t3, 0($t0)
n2d:	bne $t1, 4, nend
	sw $t3, 0($t0)
	j nend
n3:	bne $t1, 0, n3a
	sw $t3, 0($t0)
n3a:	bne $t1, 1, n3b
	bne $t2, 2, n3b
	sw $t3, 0($t0)
n3b:	bne $t1, 2, n3c
	sw $t3, 0($t0)
n3c:	bne $t1, 3, n3d
	bne $t2, 2, n3d
	sw $t3, 0($t0)
n3d:	bne $t1, 4, nend
	sw $t3, 0($t0)
	j nend
n4:	bne $t2, 0, n4a
	bgt $t1, 2, n4a
	sw $t3, 0($t0)
n4a:	bne $t2, 1, n4b
	bne $t1, 2, n4b
	sw $t3, 0($t0)
n4b:	bne $t2, 2, nend
	sw $t3, 0($t0)
	j nend
n5:	bne $t1, 0, n5a
	sw $t3, 0($t0)
n5a:	bne $t1, 1, n5b
	bne $t2, 0, n5b
	sw $t3, 0($t0)
n5b:	bne $t1, 2, n5c
	sw $t3, 0($t0)
n5c:	bne $t1, 3, n5d
	bne $t2, 2, n5d
	sw $t3, 0($t0)
n5d:	bne $t1, 4, nend
	sw $t3, 0($t0)
	j nend
n6:	bne $t1, 0, n6a
	sw $t3, 0($t0)
n6a:	bne $t1, 1, n6b
	bne $t2, 0, n6b
	sw $t3, 0($t0)
n6b:	bne $t1, 2, n6c
	sw $t3, 0($t0)
n6c:	bne $t1, 3, n6d
	beq $t2, 1, n6d
	sw $t3, 0($t0)
n6d:	bne $t1, 4, nend
	sw $t3, 0($t0)
	j nend
n7:	bne $t1, 0, n7a
	sw $t3, 0($t0)
n7a:	bne $t2, 2, nend
	sw $t3, 0($t0)
	j nend
n8:	bne $t1, 0, n8a
	sw $t3, 0($t0)
n8a:	bne $t1, 1, n8b
	beq $t2, 1, n8b
	sw $t3, 0($t0)
n8b:	bne $t1, 2, n8c
	sw $t3, 0($t0)
n8c:	bne $t1, 3, n8d
	beq $t2, 1, n8d
	sw $t3, 0($t0)
n8d:	bne $t1, 4, nend
	sw $t3, 0($t0)
	j nend
n9:	bne $t1, 0, n9a
	sw $t3, 0($t0)
n9a:	bne $t1, 1, n9b
	beq $t2, 1, n9b
	sw $t3, 0($t0)
n9b:	bne $t1, 2, n9c
	sw $t3, 0($t0)
n9c:	bne $t1, 3, n9d
	bne $t2, 2, n9d
	sw $t3, 0($t0)
n9d:	bne $t1, 4, nend
	sw $t3, 0($t0)
	j nend
n10:	bne $t1, 0, n10a
	sw $t3, 0($t0)
n10a:	bne $t2, 1, nend
	sw $t3, 0($t0)
	j nend
n11:	bne $t1, 0, n11a
	sw $t3, 0($t0)
n11a:	bne $t2, 1, n11b
	sw $t3, 0($t0)
n11b:	bne $t1, 4, nend
	bne $t2, 0, nend
	sw $t3, 0($t0)
	j nend
n12:	bne $t1, 0, n12a
	sw $t3, 0($t0)
n12a:	bne $t1, 1, n12b
	beq $t2, 1, n12b
	sw $t3, 0($t0)
n12b:	bne $t1, 2, n12c
	beq $t2, 1, n12c
	sw $t3, 0($t0)
n12c:	bne $t1, 3, n12d
	beq $t2, 2, n12d
	sw $t3, 0($t0)
n12d:	bne $t1, 4, nend
	beq $t2, 0, nend
	sw $t3, 0($t0)
	j nend
n13:	bne $t2, 0, n13a
	sw $t3, 0($t0)
n13a:	bne $t2, 1, n13b
	bne $t1, 2, n13b
	sw $t3, 0($t0)
n13b:	bne $t2, 2, nend
	beq $t1, 2, nend
	sw $t3, 0($t0)
	j nend
nend:	addi $t2, $t2, 1	# number is done being drawn in this pixel - increase iterator
	addi $t0, $t0, 4	# go to next pixel
	blt $t2, 3, nums3	# loop over 3 pixel columns
	addi $t1, $t1, 1	# increase row iterator by one when done with the previous row
	addi $t0, $t0, 500	# increase the drawing pointer accordingly -- to the next row
	blt $t1, 5, nums2	# iterate over 5 rows
	beq $a0, -2, endNums	# draw suits if the second number has already been drawn
	addi $t0, $t0, 7220 	# otherwise, this is the offset for bottom right number
	li $a0, -2 		# flag for finished drawing first card number
	j red			# go draw second card number
	
endNums:			# draw the suits now
	j drawCard		# set the drawing pointer to the correct offset for this card
suits:	addi $t0, $t0, 4792	# offset for suit square
	add $t0, $t0, $t4
	li $t1, 0		# column and row iterators
suit1:	li $t2, 0
suit2:	beq $a2, 1, spades	# these conditional branches determine which icon is being drawn
	beq $a2, 2, clubs
	beq $a2, 3, diamon
	beq $a2, 4, hearts
spades: beq $t2, 7, s0		# similar to the numbers, these icons are drawn pixel-by-pixel
	bne $t2, 1, s1		# use conditional branches to select each pixel and determine if it needs to be colored in
s0:	blt $t1, 3, s1		# if so, color it. if not, move on to the next conditional branch
	bgt $t1, 5, s1		# repeat this process until every correct pixel is colored in
	sw $t3, 0($t0)
s1:	beq $t2, 2, s1a
	bne $t2, 6, s2
s1a:	blt $t1, 2, s2
	bgt $t1, 6, s2
	sw $t3, 0($t0)
s2:	beq $t2, 5, s2a
	bne $t2, 3, s3
s2a:	blt $t1, 1, s3
	bgt $t1, 5, s3
	sw $t3, 0($t0)
s3:	bne $t2, 4, s4
	sw $t3, 0($t0)
s4:	bne $t1, 8, suitE
	blt $t2, 3, suitE
	bgt $t2, 5, suitE
	sw $t3, 0($t0)
	j suitE
diamon:	beq $t2, 7, d0			# diamonds
	bne $t2, 1, d1
d0:	bne $t1, 4, d1
	sw $t3, 0($t0)
d1:	beq $t2, 2, d1a
	bne $t2, 6, d2
d1a:	blt $t1, 3, d2
	bgt $t1, 5, d2
	sw $t3, 0($t0)
d2:	beq $t2, 5, d2a
	bne $t2, 3, d3
d2a:	blt $t1, 1, d3
	bgt $t1, 7, d3
	sw $t3, 0($t0)
d3:	bne $t2, 4, suitE
	sw $t3, 0($t0)
	j suitE
hearts:	beq $t2, 7, h0			# hearts
	bne $t2, 1, h1
h0:	blt $t1, 1, h1
	bgt $t1, 2, h1
	sw $t3, 0($t0)
h1:	beq $t2, 2, h1a
	bne $t2, 6, h2
h1a:	bgt $t1, 4, h2
	sw $t3, 0($t0)
h2:	beq $t2, 5, h2a
	bne $t2, 3, h3
h2a:	bgt $t1, 6, h3
	sw $t3, 0($t0)
h3:	bne $t2, 4, suitE
	blt $t1, 1, suitE
	sw $t3, 0($t0)
	j suitE
clubs:	beq $t2, 8, c4			# clubs
	bne $t2, 0, c0
c4:	bne $t1, 4, c0
	sw $t3, 0($t0)
c0:	beq $t2, 7, c0a
	bne $t2, 1, c1
c0a:	blt $t1, 3, c1
	bgt $t1, 5, c1
	sw $t3, 0($t0)
c1:	beq $t2, 2, c1a
	bne $t2, 6, c2
c1a:	blt $t1, 3, c2
	bgt $t1, 5, c2
	sw $t3, 0($t0)
c2:	beq $t2, 5, c2a
	bne $t2, 3, c3
c2a:	blt $t1, 1, c2b
	bgt $t1, 2, c2b
	sw $t3, 0($t0)
c2b:	bne $t1, 4, c3
	sw $t3, 0($t0)
c3:	bne $t2, 4, c5
	sw $t3, 0($t0)
c5:	bne $t1, 8, c6
	blt $t2, 2, c6
	bgt $t2, 6, c6
	sw $t3, 0($t0)
c6:	bne $t1, 7, suitE
	blt $t2, 3, suitE
	bgt $t2, 5, suitE
	sw $t3, 0($t0)
	j suitE
suitE:	addi $t2, $t2, 1		# increase iterator
	addi $t0, $t0, 4		# increase drawing pointer to next pixel
	blt $t2, 9, suit2		# continue until this row is done
	addi $t1, $t1, 1		# increase row iterator
	addi $t0, $t0, 476		# move pointer to next row
	blt $t1, 9, suit1		# continue until all rows are done
	
	jr $ra				# return to caller
	
#---------------------------------------------------------
# End of card drawing function
#---------------------------------------------------------
	
Exit:	li	$v0, 10 # end of program
	syscall
