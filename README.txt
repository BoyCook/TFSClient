=== Text File Synchroniser (client): 
A synchroniser for text based files that reside in multiple (VCS) repositories, available over HTTP(S).

=== Overview

There are two parts to TFS. A repository (REST service) that contains a list of files and their locations, and a (ruby script) client that allows users to export, update (etc) files.

Files are uniquely identified with the maven style groupId/artefactId/version concept. When a file is identified, it can be downloaded via the URL stored against it. An example of file XML is:

<file id="23">
	<id>23</id>
	<groupId>org.cccs.jslibs</groupId>
	<artefactId>jsMap</artefactId>
	<version>1.0.0.0</version>
	<extension>js</extension>
	<url>
		https://github.com/BoyCook/JSLibs/raw/master/jquery.collapsible/lib/jquery.collapsible.js
	</url>
</file>

When a file is exported TFS stores some meta-data on the filesystem in a '.tfs' directory (like SVN and Git do). This allows users to do things like upgrade versions and remove files.

=== Usage

==== search 

This will show you the files registered with the service available for download. You can provide no parameters to list all files, or you can filter by a combination of group ID, artefact ID and version:

tfs search {group ID} {artefact ID} {version}

e.g.

tfs search org.cccs.jslibs


==== export

This will download a file to your PC. You need to specify group ID, artefact ID and version to identify the file you want:

tfs export {group ID} {artefact ID} {version}

e.g.

tfs export org.cccs.jslibs jsMap 1.0.0.0


==== list

This shows all files that you've already downloaded (in your current directory):

tfs list


==== clean

This removes all files that you've already downloaded (in your current directory):

tfs clean



=== Requirements and installation

TFS is an executable ruby file so all you need to run it is ruby. It's also recommended that you add the file to your PATH. This can be done like this:

export PATH=$PATH:/{PLACE WHERE SCRIPT IS}/tfs
