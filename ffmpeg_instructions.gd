extends RichTextLabel

var win = """Install FFmpeg to take advantage of extended Trombone Charter features.

[ul]Type into the Command Prompt: [code]winget install ffmpeg[/code][/ul]

Or:

[ul]Download FFmpeg from the official site: [url]https://ffmpeg.org/download.html[/url]
Then, stick [code]ffmpeg.exe[/code] either in the Trombone Charter folder, or any folder that exists in your [code]%PATH%[/code] variable.
[ul]You can look at your [code]%PATH%[/code] by opening the Start menu and typing [code]path[/code] to bring up the search, then selecting \"Edit system environment variables\".
[ul]There's one specific to your user account, and one for the whole system.
You can add a custom one and put anything you like in it![/ul][/ul][/ul]"""

var darwin = """Install FFmpeg to take advantage of extended Trombone Charter features.

[ul]Download and install Homebrew if you don't already have it installed: [url]https://brew.sh[/url]
[ul]Copy the command found on that page into Terminal and follow the on-screen instructions[/ul]
Once installed, run the following command: [code]brew install ffmpeg[/code][/ul]"""

var nix = """Install FFmpeg to take advantage of extended Trombone Charter features.

You'll need to install [code]ffmpeg[/code] from your system's package manager.

Debian and Ubuntu-based distros:
[ul][code]apt install ffmpeg[/code][/ul]

Arch-based disros:
[ul][code]pacman -S ffmpeg[/code][/ul]

Fedora-based distros:
[ul][code]dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm[/code]
[code]dnf install ffmpeg[/code][/ul]

BSD-based systems:
[ul][code]pkg install ffmpeg[/code][/ul]

You will probably need to prefix your commands with [code]sudo[/code] depending on your distro. For other operating systems, refer to your system's documentation for installing packages. Chances are you already know what you're doing. :)"""


func _ready():
	var window : Window = get_parent()
	match OS.get_name():
		"macOS":
			text = darwin
			window.size.y = 200
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			text = nix
			window.size.y = 482
		"Windows":
			text = win
			window.size.y = 350
