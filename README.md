ProgressBar
===========

Usage
=====

This example will use your Terminal, if possible.
If your program will be started without a Terminal,
it will use kdialog for display a window.

	pb = ProgressBar.new 100, 'Initial Text...'
	pb.i += 5
	pb.inc! 5
	pb.text = 'Something different'
	pb.inc! 20
	pb.text = 'Second phase'
	pb.inc! 60
	pb.text = 'Last Steps'
	pb.inc! 20
	pb.text = 'Done!'

If you want to force to use kdialog use ProgressBar::KDialog.new or
if you want to use your Console, use ProgressBar::Console.
