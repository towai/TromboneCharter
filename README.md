# Trombone Charter
## A TMB editor for custom Trombone Champ charts.

### Features:
 * Drag-and-drop note editing.
 * Streamlined slide editing.
 * Keyboard for playing reference pitches.
 * Section preview playback.
 * Section copy.
 * Lyrics editor.

### Usage
#### Note editing
 * Click anywhere in the chart to add a note.
 * Click on a note's start to move it in time.
 * Click on a note's middle to change its pitch.
	* If a note is too small to easily grab its pitch handle, hold Shift to bring it to the front.
 * Click on a note's end to change its length and ending pitch.
 * Two notes, one beginning where the other ends, will form a slide if the pitches are the same. Changes to one of them will affect the other.
	* If you want to break a slide, hold Alt while editing one of its members.
#### Lyric editing
 * Use the button in "Editor Settings" to add a lyric.
 * The little handle right below the label can be used to drag it around.
 * The trashcan deletes the note.
 * This is all pretty much self-explanatory, right
#### Undo/Redo
 * Does:
	-use note.gd to read and store all note data, and use chart.gd to parse and edit all note data. [REDO_CHECK MOVED TO NOTE.GD]
	-propagate undone drags to connected notes. [NICE]
	-propagate undone drags to tmb_notes. [NICE]
	-fully function as an undo/redo system for a fresh chart. [***NICE***]
 * Does not:
	-register clicked notes when left unedited. [INTENDED]
	-register clicked notes (which preexisted in a loaded chart) to history log as they are edited. [UNINTENDED]
	-reset history upon loading any chart. I need a better understanding of the order in which scripts and objects are loaded.
#### Everything else
 * Hit "Preview" in Editor Settings to preview the selected section, with a metronome if the metronome checkbox is ticked.
	* Hitting Escape will end the preview early.
 * You can hold Shift when saving to bypass the Save As dialog.
	* Shift also bypasses the confirmation popup on section copy.
 * `note_color_start` and `note_color_end` will be populated iff "Use custom note colors" is checked.

### Contributing
IDK, just clone the thing and edit it using the latest 4.2 editor.

### Acknowledgements:
No copyrighted assets were used in making this. Trombone sample from GM.DLS.
Metronome click from a Roland TR-808. SVG icons by me.

Don't sell this software or claim it as your own work, lest you be haunted by the ghost of Babi.

This software is provided for free but if you want to spot me a few dollars for whatever reason,
you can find my sites at https://linktr.ee/towai
