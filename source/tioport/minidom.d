module tioport.minidom;

import tango.io.Stdout;
import tango.text.Util : trim;
//import tango.text.String;
import tango.text.Text;
//import tango.io.protocol.model.IWriter;
//import tango.io.model.IWriter;
import tioport.utils;


void check( bool aCondition, const(char)[] aMessage ){
    if( !aCondition ){
        throw new Exception( aMessage );
    }
}

class Element {
    const(char)[]         mName;
    Element[]      mChilds;
    Element        mSibling;
    char[][char[]] mAttributes;
    const(char)[]         mText;
    Element        mParent;

    this( const(char)[] aName, Element aParent ){
        mName   = aName.dup;
        mParent = aParent;
        mText   = "";
        if( aParent !is null ){
            aParent.appendChild( this );
        }
    }

    void appendChild( Element aChild ){
        if( mChilds.length > 0 ){
             mChilds[$-1].setSibling( aChild );
        }
        mChilds ~= aChild;
        aChild.mParent = this;
    }

    int getChildIdx( Element aChild ){
        foreach( int idx, Element e; mChilds ){
            if( aChild is e ){
                return idx;
            }
        }
    }
    void addChild( Element aChild, int aIdx ){
        Element[] sl = mChilds[0..aIdx];
        Element[] sr = mChilds[aIdx..$];
        Element cl = sl.length > 0 ? sl[ $-1 ] : null;
        Element cr = mChilds.length > aIdx ? mChilds[ aIdx ] : null;
        if( cl !is null ){
             cl.setSibling( aChild );
        }
        aChild.setSibling( cr );
        aChild.mParent = this;
        mChilds = sl ~ aChild ~ sr;
    }

    Element getParent(){
        return mParent;
    }

    protected void setSibling( Element aOther ){
        mSibling = aOther;
    }

    Element getSibling(){
        return mSibling;
    }

    Element getFirstChild(){
        if( mChilds.length > 0 ){
            return mChilds[0];
        }
        return null;
    }

    const(char)[] getName(){
        return mName.dup;
    }

    Element createChildElement( const(char)[] aName ){
        Element result = new Element( aName, this );
        return result;
    }

    void completeChildElement( const(char)[] aName, Element aChild ){
    }

    void completeYourself(){
        mText = .trim( mText );
    }

    const(char)[] getText(){
        return mText;
    }
    void setText( const(char)[] aText ){
        mText = aText.dup;
    }

    void addAttribute(const(char)[] key, const(char)[] value){
        mAttributes[ key.idup ] = value.dup;
    }

    void characterData (const(char)[] data){
        mText ~= data.dup;
    }

    private const(char)[] indent( int aIndent ){
        char[] result;
        for( int i; i < aIndent; i++ ){
            result ~= "  ";
        }
        return result;
    }

    string escape( const(char)[] aValue ){
        string res;
        foreach( c; aValue ){
            switch( c ){
                case '&': res ~= "&amp;"; break;
                case '"': res ~= "&quot;"; break;
                case '\'': res ~= "&apos;"; break;
                case '<': res ~= "&lt;"; break;
                case '>': res ~= "&gt;"; break;
                default: res ~= c;
            }
        }
        return res;
    }

    const(char)[] getString( int aIndent = 0 ){
        string result;
        result ~= indent( aIndent ) ~ '<' ~ mName;
        foreach(  key, value; mAttributes ){
            result ~= ' ' ~ key ~ "=\"" ~ escape( value ) ~ "\"";
        }
        if(( mChilds.length == 0 ) && ( mText.length == 0 )){
            result ~= "/>";
        }
        else{
            result ~= '>';
            if( mChilds.length > 0 ){
                result ~= '\n';
                foreach( Element child; mChilds ){
                    result ~= child.getString( aIndent+1 );
                }
                result ~= indent( aIndent );
            }
            else{
                result ~= escape( mText );
            }
            result ~= "</" ~ mName ~ '>';
        }
        result ~= '\n';
        return result;
    }
    /+
    void write( IWriter aWriter, int aIndent ){
        aWriter( indent( aIndent ) )( '<' )( mName );
        foreach( char[] key, char[] value; mAttributes ){
            aWriter( ' ' )( key )( "=\""c )( escape( value ))( "\""c );
        }
        if(( mChilds.length == 0 ) && ( mText.length == 0 )){
            aWriter( "/>"c );
        }
        else{
            aWriter( '>' );
            if( mChilds.length > 0 ){
                aWriter.newline();
                foreach( Element child; mChilds ){
                    child.write( aWriter, aIndent+1 );
                }
                aWriter( indent( aIndent ) );
            }
            else{
                aWriter( escape( mText ));
            }
            aWriter( "</"c )( mName )( '>' );
        }
        aWriter.newline();
    }
    +/
    bool hasAttribute( const(char)[] aName ){
        return cast(bool)( aName in mAttributes );
    }
    bool hasChild( const(char)[] aName ){
        foreach( Element child; mChilds ){
            if( child.mName == aName ){
                return true;
            }
        }
        return false;
    }
    Element tryGetChild( const(char)[] aName ){
        foreach( Element child; mChilds ){
            if( child.mName == aName ){
                return child;
            }
        }
        return null;
    }
    Element getChild( const(char)[] aName ){
        Element result = tryGetChild( aName );
        check( result !is null, Layouter( "Element.getChild mName={0}, aName={1}", mName, aName ) );
        return result;
    }

    void removeChilds( Element[] aChilds ){
        foreach( Element e; aChilds ){
            removeChild( e );
        }
    }

    void removeChild( Element aChild ){
        long idx = -1;
        foreach( long i, Element e; mChilds ){
            if( e is aChild ){
                idx = i;
                break;
            }
        }
        if( idx == -1 ){
            return;
        }
        if( idx > 0 && idx+1 < mChilds.length ){
            mChilds[ idx-1 ].setSibling( mChilds[ idx+1 ] );
        }
        else if( idx > 0 ){
            mChilds[ idx-1 ].setSibling( null );
        }
        mChilds = mChilds[ 0 .. idx ] ~ mChilds[ idx+1 .. $ ];
    }

    Element getChild( int aIndex ){
        return mChilds[ aIndex ];
    }
    Element[] getChilds(){
        return mChilds.dup;
    }
    uint getChildCount(){
	import std.conv:to;
	return mChilds.length.to!uint;
    }
    Element[] getChilds( const(char)[] aName ){
        Element[] result;
        foreach( Element child; mChilds ){
            if( child.mName == aName ){
                result ~= child;
            }
        }
        return result;
    }
    Element[] findChilds( bool delegate( Element aChild ) aDg ){
        Element[] result;
        foreach( Element child; mChilds ){
            if( aDg( child ) ){
                result ~= child;
            }
        }
        return result;
    }
    Element tryFindChild( bool delegate( Element aChild ) aDg ){
        foreach( Element child; mChilds ){
            if( aDg( child ) ){
                return child;
            }
        }
        return null;
    }
    Element findChild( bool delegate( Element aChild ) aDg ){
        Element result = tryFindChild( aDg );
        check( result !is null , Layouter( "Element.findChild mName={0}, not found", mName ) );
        return result;
    }
    char[] getAttribute( const(char)[] aKey ){
        check( cast(bool)(aKey in mAttributes), Layouter( "Element {0} does not contain the attribute {1}", mName, aKey ));
        return mAttributes[ aKey ].dup;
    }
}

class Document {
    private Element mElement;
    Element createRootElement( const(char)[] aName ){
        mElement = new Element( aName, null );
        return mElement;
    }
    void completeRootElement( const(char)[] aName, Element aChild ){
    }
    void setRoot( Element aRoot ){
        mElement = aRoot;
    }
    Element getRoot(){
        return mElement;
    }
    /+
    void write( IWriter aWriter ){
        aWriter( "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"c ).newline();
        mElement.write( aWriter, 0 );
        aWriter();
    }
    +/
}





