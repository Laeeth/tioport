module tioport.utils;

import tango.io.FilePath;
import tango.io.FilePath;
import tango.io.FileSystem;
import tango.text.convert.Layout;

public Layout!(char) Layouter;

public void createFolders( char[] dir ){
    auto fpath = new FilePath(  dir );
    FileSystem.toAbsolute( fpath );
    scope ddirf = new FilePath( .normalize( fpath.toUtf8 ));
    ddirf.create();
}

static this(){
    Layouter  = new Layout!(char);
}

public bool isDigit( dchar c ){
    return ( c >= '0' && c <= '9' );
}

public bool isAlpha( dchar c ){
    return ( c >= 'a' && c <= 'z' ) || ( c >= 'A' && c <= 'Z' );
}

public bool isAlphaNumeric( dchar c ){
    return isAlpha(c) || isDigit(c);
}

