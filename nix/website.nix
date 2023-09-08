{ pkgs }:
pkgs.writeTextDir "index.html" ''
<html><body>
<h1>Hello from web server.</h1>
<form>Example form.<br>
<input type="text">
</form></body></html>
''
