## SheepOS
SheepOS is an operating system in 16-bit assembly providing a command line interface and a custom file system. You can perform disk operations and make persistent changes to the files on disk. <br>
You can use SheepOS in VirtualBox. <br>

## Setup
1. **make initialize** - create and setup the VM (you must have VirtualBox installed)
2. **make build** - build the OS image and attach it to the newly created virtual disk
3. **make run** - start the VM
4. **make clean_all** - delete the VM

## How to use
- *help*: Provide a short description of all commands
- *sheep*: Print a sheep
- *list*: List all existing files
- *create*: Create a new file. A prompt will appear asking for the file name. The file must be maximum 12 characters and should not contain '_'
- *edit*: Edit an existing file. A prompt will appear asking for the name of the file you want to edit. You can write maximum 512 characters (until you reach EOF). You can type beyond EOF but only changes made before EOF will be saved on disk. Press esc or enter to save changes
- *view*: View a file's contents. A prompt will appear asking for the name of the file you want to view.
- *delete*: Delete a file. A prompt will appear asking for the name of the file you want to delete