/*
 *  Copyright (C) 2006 Frank Benoit <benoit@tionex.de>
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty.  In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  1. The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  2. Altered source versions must be plainly marked as such, and must not be
 *     misrepresented as being the original software.
 *  3. This notice may not be removed or altered from any source distribution.
 */
module tioport.tioport;

import tioport.utils;
import tioport.refactorings;
import tioport.parts;
import tioport.resolve;
import tioport.dmodwriter;

import tango.core.Memory;

import     tango.text.Util : replace, delimit;
import           tango.text.convert.Integer;
import           tango.io.Stdout;
import           tango.io.Console;
//import           tango.io.Buffer;
import           tango.io.stream.TextFile; // FileConduit
import tango.io.model.IFile; // FileConst
//FileSystem;
//import           tango.io.FileConduit;
//import           tango.io.FileConst;
import           tango.io.FilePath;
//import           tango.io.protocol.Writer;
import           tioport.minidom;
//import tango.util.collection.LinkSeq;
import tango.util.container.LinkedList;
alias LinkSeq = LinkedList;
import std.exception;
//import             mango.xml.sax.Exceptions;
//import             mango.xml.sax.DefaultSAXHandler;
//import             mango.xml.sax.model.ISAXParser;
//import             mango.xml.sax.parser.teqXML;
//private import mango.xml.sax.model.ISAXHandler;
import kxml.xml;

const char       pathSep = FileConst.PathSeparatorChar;
private int gAnonymousClassId;

// if nowrite is set, than only the method declarations are read, not the content in the slist.
bool getImplementation_state = false;

bool getImplementation(){
    return getImplementation_state;
}
char[] mMixinTree;

bool readXmlFile(const(char)[] aFilename, Document aDocument){

    FilePath aFilePath = new FilePath( aFilename );

    alias LinkSeq!(Element) TElementList;

    TElementList mElements = new TElementList();

    auto parser = new XMLReader!(char)();
    auto conduit = new FileConduit( aFilePath );

    parser.parse ( conduit, new class DefaultSAXHandler!(char){
            void startDocument() {
            }
            void endDocument() {
            }
            void startElement(const(char)[] name) {

                Element el;
                if( mElements.size() > 0 ){
                    el = mElements.head().createChildElement( name );
                    mElements.prepend( el );
                }
                else{
                    el = aDocument.createRootElement( name );
                    mElements.prepend( el );
                }
            }
            void addAttribute(const(char)[] key, const(char)[] value) {
                Element el = mElements.head();
                el.addAttribute(key.dup, value.dup);
            }
            void endElement(const(char)[] name) {
                Element child = mElements.take();
                char[] child_name = child.getName();
                child.completeYourself();
                if( mElements.size() > 0 ){
                    Element el = mElements.head();
                    el.completeChildElement( child_name, child );
                }
                else{
                    aDocument.completeRootElement( child_name, child );
                }
            }
            void characterData (const(char)[] data, CDataStatus status) {
                Element el = mElements.head();
                el.characterData( data );
            }
            } );

    Stdout.flush();
    conduit.close;

    return(true);
}

void usage(const(char)[] aCommand){
    Stdout.formatln("Usage: {0} <cfg-tioport.xml>", aCommand);
}

char[] ddir = ".".dup;
private bool   writeInternals = false;

char[] getDDir(){
    return ddir.dup;
}

int main(string[] args)
{
    if (aArgs.length != 2) {
        usage(aArgs[0]);
        return(1);
    }
    char[]       cfgName = aArgs[1].dup;

    CfgDocument  cfgdoc = new CfgDocument();
    if (!readXmlFile(cfgName, cfgdoc)) {
        //cfgdoc.write( new TextFileOutput( Stdout.buffer));
        cfgdoc.write( new Writer( Stdout.buffer));
        return(1);
    }

    Element      root     = cfgdoc.getRoot();

    Header[] headers;
    foreach (Element e; root.getChilds("header")) {
        Header hdr = new Header();
        hdr.mFqnStart = e.getAttribute( "fqn-start" );
        hdr.mText = e.getText();
        headers ~= hdr;
    }

    writeInternals = root.getAttribute( "writeinternals" ) == "true";

    char[] extractAttr( const(char)[] id ){
        if( ! root.hasAttribute( id )){
            throw new Exception( "the configuration root element needs the attribute "~id );
        }
        return root.getAttribute( id );
    }
    mMixinTree = extractAttr( "mixintree" );

    gJavaIntern.mIsNowrite = !writeInternals;

    ddir = extractAttr( "ddir" );
    Stdout.formatln("create {0} ", ddir);
    createFolders( ddir );
    char[] xmldir      = extractAttr( "xmldir" );
    PModifiers.mExternIdent = extractAttr( "extern" );

    Element[]    eClasses = root.getChilds("class");
    Stdout.formatln("loading {0} file(s)", eClasses.length);
    gc.disable();
    int i = 0;
    foreach (Element e; eClasses) {
        char[]    fqn        = e.getAttribute("fqn");
        char[]    fileName   = xmldir ~ pathSep ~ .replace(fqn.dup, '.', pathSep) ~ ".java.xml";
        char[]    moduleName = .delimit(fqn, ".")[$ -1];

        getImplementation_state = true;
        if (e.hasAttribute("stub") && e.getAttribute("stub") == "true") {
            getImplementation_state = false;
        }
        if (e.hasAttribute("nowrite") && e.getAttribute("nowrite") == "true") {
            getImplementation_state = false;
        }

        //Stdout.format("loading {0} ... ", fileName);
        Stdout.flush();
        JDocument doc = new JDocument();
        if (!readXmlFile(fileName, doc)) {
            doc.write( new Writer( Stdout.buffer ));
            return(1);
        }
        EJava     ej  = doc.getRootEJava();
        PModule   mod = ej.buildParts(getPackageRoot(), moduleName);

        if (e.hasAttribute("nowrite") && e.getAttribute("nowrite") == "true") {
            mod.mIsNowrite = true;
        }
        if (e.hasAttribute("stub") && e.getAttribute("stub") == "true") {
            mod.mIsStub = true;
        }

        foreach (Element xch; e.getChilds( "exchange" )) {
            char[] funcname = xch.getAttribute( "funcname" );
            char[] text     = xch.getAttribute( "text" );
            mod.mExchangeFuncs[ funcname.dup ] = text.dup;
        }

        foreach( Header hdr; headers ){
            if( fqn.length >= hdr.mFqnStart.length && fqn[0 .. hdr.mFqnStart.length] == hdr.mFqnStart ){
                mod.mHeaderText ~= hdr.mText;
                mod.mHeaderText ~= '\n'; //TODO a newline is not parsed from enki, if it is at the end of a element text. is this a bug?
            }
        }

        //Stdout.formatln("OK");
        i++;
        if( i > 200 ){
            i = 0;
        //    gc.enable();
        //    gc.collect();
        //    gc.disable();
        }
    }
    gc.enable();
    //gc.collect();

    Stdout.formatln("Stage 1 ...");
    resolveStage1();
    refactoreStage1( writeInternals );
    Stdout.formatln("Stage 2 ...");
    resolveStage2();
    refactoreStage2();
    Stdout.formatln("Stage 3 ...");
    resolveStage3();
    Stdout.formatln("Refactoring ...");
    PModule staticctors = getPackageRoot().createFqnModule( root.getChild( "staticctors" ).getAttribute( "fqn" ));
    refactoreStage3( staticctors );
    Stdout.formatln("Writing ...");
    writeAllModuleFromPackage(getPackageRoot());
    return(0);
}

class Header{
    char[] mFqnStart;
    char[] mText;
}

void writeAllModuleFromPackage(PPackage aPackage){
    foreach (PModule m; aPackage.getModules()) {
        writeDModule( ddir, mMixinTree, m );
    }
    foreach (PPackage p; aPackage.getPackages()) {
        writeAllModuleFromPackage(p);
    }
}


class CfgDocument : Document {
}

class JDocument : Document {
    private EJava mRoot;

    override Element createRootElement(const(char)[] aName){
        assert(aName == "java");
        EJava e = new EJava(aName, null);
        setRoot(e);
        mRoot = e;
        return(e);
    }

    EJava getRootEJava(){
        return(mRoot);
    }
}

template StdImpl(){
    this(const(char)[] aName, Element aParent){
        super(aName, aParent);
    }
}

class JElement : Element {
    char[]       getAttrText(){
        return(getAttribute("text"));
    }


    this(const(char)[] aName, Element aParent){
        super(aName, aParent);
    }

    PPackage buildPackages(PPackage aRoot, Element e){
        if( e is null ){
            return aRoot;
        }
        Ident    i = makeIdentifier(e.getChilds()[1]);

        if (i.mIdents.length == 0) {
            return(aRoot);
        }
        PPackage p = aRoot;
        do {
            p         = p.getOrCreatePackage(i.mIdents[0]);
            i.mIdents = i.mIdents[1 .. $];
        } while (i.mIdents.length > 0);
        return(p);
    }

    PClassDef buildInterfaceDef(Element e){
        return(null);
    }

    PTypeRef getTypeRef(){
        PTypeRef tr = new PTypeRef;

        switch (getName()) {
        case "IDENT":
            tr.mParts ~= new PTypeRefPart(getAttribute("text"));
            return(tr);

        case "DOT":
            Ident i = makeIdentifier(this);
            foreach (char[] t; i.mIdents) {
                tr.mParts ~= new PTypeRefPart(t);
            }
            return(tr);

        case "LITERAL_void":
        case "LITERAL_byte":
        case "LITERAL_short":
        case "LITERAL_int":
        case "LITERAL_float":
        case "LITERAL_long":
        case "LITERAL_double":
        case "LITERAL_char":
        case "LITERAL_boolean":
            tr.mParts ~= new PTypeRefPart(getAttribute("text"));
            return(tr);

        default:
            assert(false, getName());
        }
    }


    char[] getTrace(){
        char[] trace;
        Element e = this;
        while( e !is null ){
            trace ~= getName();
            if( hasAttribute( "text" )){
                trace ~= " ";
                trace ~= getAttribute( "text" );
            }
            trace ~= "\n";
            e = e.getParent();
        }
        return trace;
    }

    PTypeRef buildTypeRefPath(Element c){
        Ident    i  = makeIdentifier(c);
        PTypeRef tr = new PTypeRef;

        foreach ( str; i.mIdents) {
            PTypeRefPart trp = new PTypeRefPart;
            trp.mText = str;
            tr.mParts ~= trp;
        }
        return(tr);
    }

    char[] getIdent(Element e){
        return(e.getAttribute("text"));
    }

    override Element createChildElement(const(char)[] aName){
        switch (aName) {
        case "EMPTY_STAT":
            return(new EEmptyStat(aName, this));

        case "LABELED_STAT":
            return(new ELabeledStat(aName, this));

        case "PACKAGE_DEF":
            return(new EPackageDef(aName, this));

        case "ANNOTATIONS":
            return(new EAnnotations(aName, this));

        case "IMPORT":
        case "STATIC_IMPORT":
            return(new EImport(aName, this));

        case "CLASS_DEF":
            return(new EClassDef(aName, this));

        case "INTERFACE_DEF":
            return(new EInterfaceDef(aName, this));

        case "ENUM_DEF":
            return(new EEnumDef(aName, this));

        case "ENUM_CONSTANT_DEF":
            return(new EEnumConstantDef(aName, this));

        case "ANNOTATION_DEF":
            return(new EAnnotationDef(aName, this));

        case "OBJBLOCK":
            return(new EObjBlock(aName, this));

        case "VARIABLE_DEF":
            return(new EVariableDef(aName, this));

        case "MODIFIERS":
            return(new EModifiers(aName, this));

        case "CTOR_DEF":
            return(new ECtorDef(aName, this));

        case "PARAMETERS":
            return(new EParameters(aName, this));

        case "PARAMETER_DEF":
        case "VARIABLE_PARAMETER_DEF":
            return(new EParameterDef(aName, this));

        case "SLIST":
            return(new ESList(aName, this));

        case "METHOD_DEF":
            return(new EMethodDef(aName, this));

        case "ARRAY_INIT":
            return(new EArrayInit(aName, this));

        case "TYPE":
            return(new EType(aName, this));

        case "TYPE_PARAMETERS":
            return(new ETypeParameters(aName, this));

        case "TYPE_PARAMETER":
            return(new ETypeParameter(aName, this));

        case "TYPE_ARGUMENTS":
            return(new ETypeArguments(aName, this));

        case "TYPE_ARGUMENT":
            return(new ETypeArgument(aName, this));

        case "ARRAY_DECLARATOR":
            return(new ENewArrayDeclarator(aName, this));

        case "STATIC_INIT":
            return(new EStaticInit(aName, this));

        case "INSTANCE_INIT":
            return(new EInstanceInit(aName, this));

        case "ELIST":
            return(new EEList(aName, this));

        case "EXPR":
            return(new EExpr(aName, this));

        case "LITERAL_synchronized":
            return(new ESynchronized(aName, this));

        case "LITERAL_assert":
            return(new EAssert(aName, this));

        case "LITERAL_return":
            return(new EReturn(aName, this));

        case "LITERAL_try":
            return(new ELiteralTry(aName, this));

        case "LITERAL_catch":
            return(new ELiteralCatch(aName, this));

        case "LITERAL_finally":
            return(new ELiteralFinally(aName, this));

        case "LITERAL_if":
            return(new ELiteralIf(aName, this));

        case "LITERAL_for":
            return(new ELiteralFor(aName, this));

//        case "FOR_INIT":
//            return(new EForInit(aName, this));
//
//        case "FOR_CONDITION":
//            return(new EForCondition(aName, this));
//
//        case "FOR_ITERATOR":
//            return(new EForIterator(aName, this));
//
//        case "FOR_EACH_CLAUSE":
//            return(new EForEachClause(aName, this));

        case "LITERAL_switch":
            return(new ELiteralSwitch(aName, this));

        case "LITERAL_do":
            return(new ELiteralDo(aName, this));

        case "LITERAL_while":
            return(new ELiteralWhile(aName, this));

        case "CASE_GROUP":
            return(new ECaseGroup(aName, this));

        case "LITERAL_break":
        case "LITERAL_continue":
            return(new ELiteralBreakContinue(aName, this));


        case "ASSIGN":
        case "PLUS_ASSIGN":
        case "MINUS_ASSIGN":
        case "STAR_ASSIGN":
        case "DIV_ASSIGN":
        case "MOD_ASSIGN":
        case "SR_ASSIGN":
        case "BSR_ASSIGN":
        case "SL_ASSIGN":
        case "BAND_ASSIGN":
        case "BXOR_ASSIGN":
        case "BOR_ASSIGN":
            return(new EExprAssign(aName, this));

        case "QUESTION":
            return(new EExprQuestion(aName, this));

        case "LOR":
        case "LAND":
        case "BOR":
        case "BXOR":
        case "BAND":
        case "NOT_EQUAL":
        case "EQUAL":
        case "LT":
        case "GT":
        case "LE":
        case "GE":
        case "SL":
        case "SR":
        case "BSR":
        case "PLUS":
        case "MINUS":
        case "DIV":
        case "MOD":
        case "STAR":
        case "LITERAL_instanceof":
            return(new EExprBinary(aName, this));

        case "POST_INC":
        case "POST_DEC":
        case "INC":
        case "DEC":
        case "BNOT":
        case "LNOT":
        case "UNARY_MINUS":
        case "UNARY_PLUS":
            return(new EExprUnary(aName, this));

        case "INDEX_OP":
            return(new EExprIndexOp(aName, this));

        case "METHOD_CALL":
            return(new EExprMethodCall(aName, this));

        case "TYPECAST":
            return(new EExprTypeCast(aName, this));

        case "LITERAL_new":
            return(new EExprNew(aName, this));

            // const
        case "NUM_INT":
        case "NUM_FLOAT":
        case "NUM_DOUBLE":
        case "NUM_LONG":
        case "CHAR_LITERAL":
        case "STRING_LITERAL":
        case "LITERAL_true":
        case "LITERAL_false":
        case "LITERAL_null":
        case "LITERAL_class":
            return(new EExprLiteral(aName, this));

        case "LITERAL_super":
            return(new EExprLiteralSuper(aName, this));

        case "SUPER_CTOR_CALL":
        case "CTOR_CALL":
            return(new ECtorCall(aName, this));

        case "LITERAL_throw":
            return(new EExprLiteralThrow(aName, this));

        case "LITERAL_this":
            return(new EExprLiteralThis(aName, this));

        case "IDENT":
            return(new EIdent(aName, this));

        case "DOT":
            return(new EDot(aName, this));

        case "LITERAL_void":
        case "LITERAL_byte":
        case "LITERAL_short":
        case "LITERAL_int":
        case "LITERAL_float":
        case "LITERAL_long":
        case "LITERAL_double":
        case "LITERAL_char":
        case "LITERAL_boolean":
            return(new ELiteralBuildinType(aName, this));

        default:
            return(new JElement(aName, this));
        }
    }
}

PModule currentModule;

class EJava : JElement {
    char[] mModName;
    char[] mModPath;

    mixin StdImpl!();

    PModule buildParts(PRootPackage aPackageRoot, const(char)[] aModuleName){
        EPackageDef epackdef = cast(EPackageDef)getFirstChild();

        PPackage ppack = buildPackages(aPackageRoot, epackdef);
        PModule  pmod  = ppack.createModule(aModuleName);
        gAnonymousClassId = 0;
        currentModule = pmod;

        foreach (Element e; getChilds()) {
            char[] type = e.getName();
            switch (type) {
            case "PACKAGE_DEF":
                break;

            case "IMPORT":
            case "STATIC_IMPORT":
                {
                    EImport imp = cast(EImport)e;
                    pmod.mImports ~= imp.buildImportDef();
                }
                break;

            case "CLASS_DEF":
            case "INTERFACE_DEF":
            case "ENUM_DEF":
                {
                    ETypeDef etype = cast(ETypeDef)e;
                    pmod.mTypeDefs ~= etype.buildTypeDef( pmod );
                }
                break;

            case "ANNOTATION_DEF":
                // ignore
                break;

            default:
                assert(false);
                break;
            }
        }
        return(pmod);
    }
}

class EPackageDef : JElement {
    mixin StdImpl!();
}

class EEmptyStat : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        PExpr e = new PExpr();
        e.mAsStatement = true;
        return e;
    }
}

class ELabeledStat : EStat {
    mixin StdImpl!();
    override PVarDef getPartStatement(){
        PStatLabeled stat = new PStatLabeled;

        stat.mName = getChild(0).getAttribute("text");
        stat.mStat = (cast(EStat)getChild(1)).getPartStatement();
        return(stat);
    }
}

class EAnnotations : JElement {
    mixin StdImpl!();
}

class EImport : JElement {
    mixin StdImpl!();

    PImport buildImportDef(){
        IdentStar i = makeIdentifierStar(getFirstChild);

        return(new PImport(i.mIdents, i.mStar, getName() == "STATIC_IMPORT"));
    }
}

class ETypeDef : JElement {
    mixin StdImpl!();

    PTypeDef buildTypeDef( PModule aModule ){
        switch (getName()) {
        case "CLASS_DEF":
            return((cast(EClassDef)this).getPartClassDef( aModule ));

        case "ENUM_DEF":
            return((cast(EEnumDef)this).getPartEnumDef( aModule ));

        case "INTERFACE_DEF":
            return((cast(EInterfaceDef)this).getPartInterfaceDef( aModule ));
        }
    }

    PClassDef getPartEnumDef( PModule aModule ){
        PClassDef classDef = new PClassDef(aModule);
        classDef.mModule = aModule;
        Element   c        = getFirstChild();

        assert(c.getName() == "MODIFIERS");
        classDef.mModifiers = (cast(EModifiers)c).getPartModifiers();

        c = c.getSibling();

        assert(c.getName() == "IDENT");
        classDef.mName = (cast(EIdent)c).getAttrText();

        c = c.getSibling();

        if (c.getName() == "TYPE_PARAMETERS") {
            c = c.getSibling();
        }

        assert(c.getName() == "IMPLEMENTS_CLAUSE");
        foreach (Element v; c.getChilds()) {
            if( v.getName() == "TYPE_ARGUMENTS" ){
                continue;
            }
            classDef.mSuperIfaces ~= buildTypeRefPath(v);
        }

        c = c.getSibling();

        EObjBlock objBlock = cast(EObjBlock)c;
        objBlock.fillPartClassDef(classDef);
        return(classDef);
    }
    PClassDef getPartClassDef( PModule aModule ){
        PClassDef classDef = new PClassDef(aModule);
        classDef.mModule = aModule;
        Element   c        = getFirstChild();

        assert(c.getName() == "MODIFIERS");
        classDef.mModifiers = (cast(EModifiers)c).getPartModifiers();

        c = c.getSibling();

        assert(c.getName() == "IDENT");
        classDef.mName = (cast(EIdent)c).getAttrText();

        c = c.getSibling();

        if (c.getName() == "TYPE_PARAMETERS") {
            c = c.getSibling();
        }
        assert(c.getName() == "EXTENDS_CLAUSE", c.getName());
        if (Element v = c.getFirstChild()) {
            classDef.mSuperClass = buildTypeRefPath(v);
        }

        c = c.getSibling();

        assert(c.getName() == "IMPLEMENTS_CLAUSE");
        foreach (Element v; c.getChilds()) {
            if( v.getName() == "TYPE_ARGUMENTS" ){
                continue;
            }
            classDef.mSuperIfaces ~= buildTypeRefPath(v);
        }

        c = c.getSibling();

        EObjBlock objBlock = cast(EObjBlock)c;
        objBlock.fillPartClassDef(classDef);
        return(classDef);
    }
}
class EClassDef : ETypeDef {
    mixin StdImpl!();
}

class EInterfaceDef : ETypeDef {
    mixin StdImpl!();
    PInterfaceDef getPartInterfaceDef( PModule aModule ){
        PInterfaceDef def = new PInterfaceDef(aModule);
        def.mModule = aModule;
        Element       c   = getFirstChild();

        def.mModifiers = (cast(EModifiers)c).getPartModifiers();
        c              = c.getSibling();
        def.mName      = (cast(EIdent)c).getAttrText();
        c              = c.getSibling();
        if (c.getName() == "TYPE_PARAMETERS") {
            c = c.getSibling();
        }
        assert(c.getName() == "EXTENDS_CLAUSE");
        foreach (Element ext; c.getChilds()) {
            def.mSuperIfaces ~= buildTypeRefPath(ext);
        }
        c = c.getSibling();
        assert(c.getName() == "OBJBLOCK");
        foreach (EMethodDef v; cast(EMethodDef[])c.getChilds("METHOD_DEF")) {
            PMethodDef mthd = v.buildPartMethodDef( true );
            if( mthd ){
                def.mMethods ~= mthd;
            }
        }
        return(def);
    }
}

class EEnumDef : ETypeDef {
    mixin StdImpl!();
}

class EEnumConstantDef : JElement {
    mixin StdImpl!();
}

class EAnnotationDef : JElement {
    mixin StdImpl!();
}

class EObjBlock : JElement {
    mixin StdImpl!();
    void fillPartClassDef(PClassDef classDef){
        foreach( JElement child; cast(JElement[]) getChilds() ){
            char[] type = child.getName();
            switch( type ){
                case "VARIABLE_DEF":
                {
                    EVariableDef v= cast(EVariableDef)child;
                    PFieldDef fld = v.buildPartField();
                    if( fld ){
                        classDef.mFields ~= fld;
                        classDef.mOriginalDeclOrder ~= fld;
                    }
                }
                break;
                case "CLASS_DEF":
                {
                    EClassDef v = cast(EClassDef)child;
                    PTypeDef pd = v.buildTypeDef(currentModule);
                    pd.mParent = classDef;
                    classDef.mTypeDefs ~= pd;
                    classDef.mOriginalDeclOrder ~= pd;
                }
                break;
                case "ENUM_DEF":
                {
                    EEnumDef v= cast(EEnumDef)child;
                    PTypeDef pd = v.buildTypeDef(currentModule);
                    pd.mParent = classDef;
                    classDef.mTypeDefs ~= pd;
                    classDef.mOriginalDeclOrder ~= pd;
                }
                break;
                case "INTERFACE_DEF":
                {
                    EInterfaceDef v= cast(EInterfaceDef)child;
                    PTypeDef pd = v.buildTypeDef(currentModule);
                    pd.mParent = classDef;
                    classDef.mTypeDefs ~= pd;
                    classDef.mOriginalDeclOrder ~= pd;
                }
                break;
                case "STATIC_INIT":
                {
                    if( getImplementation() ){
                        EStaticInit v= cast(EStaticInit)child;
                        PStaticCtor p = v.buildPartStaticInit();
                        classDef.mStaticCtors ~= p;
                        classDef.mOriginalDeclOrder ~= p;
                    }
                }
                break;
                case "INSTANCE_INIT":
                {
                    if( getImplementation() ){
                        EInstanceInit v= cast(EInstanceInit)child;
                        PInstanceInit p =  v.buildPartInstanceInit();
                        classDef.mInstanceInits ~= p;
                        classDef.mOriginalDeclOrder ~= p;
                    }
                }
                break;
                case "CTOR_DEF":
                {
                    ECtorDef v= cast(ECtorDef)child;
                    PCtor p =  v.buildPartCtor();
                    if( p ){
                        classDef.mCtors ~= p;
                        classDef.mOriginalDeclOrder ~= p;
                    }
                }
                break;
                case "METHOD_DEF":
                {
                    EMethodDef v= cast(EMethodDef)child;
                    PMethodDef mthd = v.buildPartMethodDef( false );
                    if( mthd ){
                        classDef.mMethods ~= mthd;
                        classDef.mOriginalDeclOrder ~= mthd;
                    }

                }
                break;
                default:
                    assert( false, type );
            }
        }
    }
}

class EVariableDef : EStat {
    mixin StdImpl!();

    PFieldDef buildPartField(){
        PFieldDef fld = new PFieldDef( currentModule );

        fld.mModifiers = (cast(EModifiers)getChild("MODIFIERS")).getPartModifiers();
        fld.mName      = getChild("IDENT").getAttribute("text");
        fld.mTypeInst  = (cast(EType)getChild("TYPE")).getPartTypeInst();
        if( !getImplementation() ){
            if( fld.mModifiers.mProtection != Protection.PUBLIC && fld.mModifiers.mProtection != Protection.PROTECTED){
                return null;
            }
        }
        if( getImplementation() ){
            if (EExprAssign assign = cast(EExprAssign)tryGetChild("ASSIGN")) {
                fld.mInitializer = assign.getPartVarInitializer();
            }
        }
        return(fld);
    }
    PVarDef getPartVariableDef(){
        PVarDef fld = new PVarDef( currentModule );

        fld.mModifiers = (cast(EModifiers)getChild("MODIFIERS")).getPartModifiers();
        fld.mName      = getChild("IDENT").getAttribute("text");
        fld.mTypeInst  = (cast(EType)getChild("TYPE")).getPartTypeInst();
        if( !getImplementation() ){
            if( fld.mModifiers.mProtection != Protection.PUBLIC && fld.mModifiers.mProtection != Protection.PROTECTED){
                return null;
            }
        }
        if( getImplementation() ){
            if (EExprAssign assign = cast(EExprAssign)tryGetChild("ASSIGN")) {
                fld.mInitializer = assign.getPartVarInitializer();
            }
        }
        return(fld);
    }
    override PVarDef getPartStatement(){
        PLocalVarDef var = new PLocalVarDef( currentModule );

        var.mModifiers = (cast(EModifiers)getChild("MODIFIERS")).getPartModifiers();
        var.mName      = getChild("IDENT").getAttribute("text");
        var.mTypeInst  = (cast(EType)getChild("TYPE")).getPartTypeInst();
        if( !getImplementation() ){
            if( var.mModifiers.mProtection != Protection.PUBLIC && var.mModifiers.mProtection != Protection.PROTECTED){
                return null;
            }
        }
        if( getImplementation() ){
            if (EExprAssign assign = cast(EExprAssign)tryGetChild("ASSIGN")) {
                var.mInitializer = assign.getPartVarInitializer();
            }
        }
        return(var);
    }
}

class EModifiers : JElement {
    mixin StdImpl!();
    bool       mExternC    = false;
    bool       mAllowConst = false;
    enum Visibility {
        PRIVATE, PROTECTED, PUBLIC, PACKAGE, NOTHING
    }
    Visibility mVisibility = Visibility.NOTHING;

    PModifiers getPartModifiers(){
        PModifiers mod = new PModifiers;

        if (hasChild("LITERAL_private")) {
            mod.mProtection = Protection.PRIVATE;
        }
        else if (hasChild("LITERAL_protected")) {
            mod.mProtection = Protection.PROTECTED;
        }
        else if (hasChild("LITERAL_public")) {
            mod.mProtection = Protection.PUBLIC;
        }
        mod.mStatic       = hasChild("LITERAL_static");
        mod.mAbstract     = hasChild("ABSTRACT");
        mod.mTransient    = hasChild("LITERAL_transient");
        mod.mFinal        = hasChild("FINAL");
        mod.mNative       = hasChild("LITERAL_native");
        mod.mThreadsafe   = hasChild("LITERAL_threadsafe");
        mod.mSynchronized = hasChild("LITERAL_synchronized");
        mod.mConst        = hasChild("LITERAL_const");
        mod.mVolatile     = hasChild("LITERAL_volatile");
        mod.mStrictfp     = hasChild("STRICTFP");
        return(mod);
    }
}

class ECtorDef : JElement {
    mixin StdImpl!();
    PCtor buildPartCtor(){
        PCtor ctor = new PCtor;

        ctor.mModifiers = (cast(EModifiers)getChild("MODIFIERS")).getPartModifiers();

        if( !getImplementation() ){
            if( ctor.mModifiers.mProtection != Protection.PUBLIC && ctor.mModifiers.mProtection != Protection.PROTECTED){
                return null;
            }
        }

        foreach (EParameterDef p; cast(EParameterDef[])(getChild("PARAMETERS").getChilds())) {
            ctor.mParams ~= p.getPartParameterDef();
        }
        if (ESList slist = cast(ESList)getChild("SLIST")) {
            ctor.mStatList = slist.getPartStatement();
        }
        return(ctor);
    }
}

class EParameters : JElement {
    mixin StdImpl!();
}

class EParameterDef : JElement {
    mixin StdImpl!();
    PParameterDef getPartParameterDef(){
        PParameterDef p = new PParameterDef( currentModule );

        Element[]     childs = getChilds();
        p.mModifiers = (cast(EModifiers)childs[0]).getPartModifiers();
        p.mTypeInst  = (cast(EType)childs[1]).getPartTypeInst();
        p.mName      = (cast(EIdent)childs[2]).getAttrText();
        p.mIsVariableLength = ( getName == "VARIABLE_PARAMETER_DEF" );
        return(p);
    }
}
void appendNotNull( T, E )( inout T t, E e ){
    if( e ){
        t ~= e;
    }
}
class ESList : EStat {
    mixin StdImpl!();
    override PStatList getPartStatement(){
        PStatList p = new PStatList;

        if( getImplementation() ){
            foreach (Element s; getChilds()) {
                if (EStat stat = cast(EStat)s) {
                    appendNotNull( p.mStats, stat.getPartStatement() );
                }
            }
        }
        return(p);
    }
}

class EMethodDef : EStat {
    mixin StdImpl!();

    override PStatement getPartStatement(){
        return(buildPartMethodDef( false ));
    }
    PMethodDef buildPartMethodDef( bool isInterface = false ){
        PMethodDef mthd = new PMethodDef;

        mthd.mModifiers  = (cast(EModifiers)getChild("MODIFIERS")).getPartModifiers();
        mthd.mReturnType = (cast(EType)getChild("TYPE")).getPartTypeInst();
        mthd.mName       = getChild("IDENT").getAttribute("text");

        if( !getImplementation() && !isInterface ){
            if( mthd.mModifiers.mProtection != Protection.PUBLIC && mthd.mModifiers.mProtection != Protection.PROTECTED){
                return null;
            }
        }
        foreach (EParameterDef p; cast(EParameterDef[])(getChild("PARAMETERS").getChilds())) {
            mthd.mParams ~= p.getPartParameterDef();
        }
        if (ESList slist = cast(ESList)tryGetChild("SLIST")) {
            mthd.mStatList = slist.getPartStatement();
        }
        return(mthd);
    }
}

class EArrayInit : JElement {
    mixin StdImpl!();

    PVarInitArray getPartVarInitArray(){
        PVarInitArray ia = new PVarInitArray();

        foreach (Element e; getChilds()) {
            switch (e.getName()) {
            case "EXPR":
                ia.mInitializers ~= (cast(EExpr)e).getPartVarInitExpr();
                break;

            case "ARRAY_INIT":
                ia.mInitializers ~= (cast(EArrayInit)e).getPartVarInitArray();
                break;

            default:
                assert(false);
                break;
            }
        }
        return(ia);
    }
}

class EType : JElement {
    mixin StdImpl!();

    PTypeInst getPartTypeInst(){
        PTypeInst ti = new PTypeInst;

        Element   cur = getFirstChild();

        while (cur.getName() == "ARRAY_DECLARATOR") {
            ti.mDimensions++;
            cur = cast(JElement)cur.getFirstChild();
        }
        void makeSimpleType(const(char)[] aName) {
            ti.mTypeRef = new PTypeRef;
            PTypeRefPart trp = new PTypeRefPart;
            trp.mText = aName;
            ti.mTypeRef.mParts ~= trp;
        }
        switch (cur.getName) {
        case "LITERAL_void":
        case "LITERAL_byte":
        case "LITERAL_short":
        case "LITERAL_int":
        case "LITERAL_float":
        case "LITERAL_long":
        case "LITERAL_double":
        case "LITERAL_char":
        case "LITERAL_boolean":
            makeSimpleType(cur.getAttribute("text"));
            break;

        case "IDENT":
        case "DOT":
            ti.mTypeRef = buildTypeRefPath(cur);
            break;

        case "TYPE_ARGUMENTS":
            break;

        default:
            assert(false, cur.getName());
        }
        return(ti);
    }

    override Element createChildElement(const(char)[] aName){
        switch (aName) {
        case "ARRAY_DECLARATOR":
            return(new EArrayDeclarator(aName, this));

        default:
            return(super.createChildElement(aName));
        }
    }
}

class EStaticInit : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        return buildPartStaticInit();
    }
    PStaticCtor buildPartStaticInit(){
        PStaticCtor ctor = new PStaticCtor;
        ctor.mModifiers = new PModifiers;
        ctor.mModifiers.mStatic = true;

        if (ESList slist = cast(ESList)getChild("SLIST")) {
            ctor.mStatList = slist.getPartStatement();
        }
        return(ctor);
    }
}

class EInstanceInit : EStat {
    mixin StdImpl!();

    override PStatement getPartStatement(){
        return buildPartInstanceInit();
    }
    PInstanceInit buildPartInstanceInit(){
        PInstanceInit init = new PInstanceInit;

        if (ESList slist = cast(ESList)getChild("SLIST")) {
            init.mStatList = slist.getPartStatement();
        }
        return(init);
    }
}

class ETypeParameters : JElement {
    mixin StdImpl!();
}

class ETypeParameter : JElement {
    mixin StdImpl!();
}

class ETypeArguments : JElement {
    mixin StdImpl!();
}

class ETypeArgument : JElement {
    mixin StdImpl!();
}

abstract class EExpression : JElement {
    mixin StdImpl!();
    abstract PExpr getPartExpr();
}

class EExpr : EStat {
    mixin StdImpl!();
    PVarInitExpr getPartVarInitExpr(){
        PVarInitExpr ie = new PVarInitExpr;

        ie.mExpr = getPartExpr();
        return(ie);
    }
    override PStatement getPartStatement(){
        PExpr res = getPartExpr();

        res.mAsStatement = true;
        return(res);
    }
    PExpr getPartExpr(){
        EExpression e = cast(EExpression)getFirstChild();

        assert(e);
        return(e.getPartExpr());
    }

    override Element createChildElement(const(char)[] aName){
        switch (aName) {
        case "ARRAY_DECLARATOR":
            return(new EArrayDeclarator(aName, this));

        default:
            return(super.createChildElement(aName));
        }
    }
}

class EEList : JElement {
    mixin StdImpl!();

    PExpr[] getPartEList(){
        PExpr[] res;
        foreach (EExpr e; cast(EExpr[])getChilds()) {
            res ~= e.getPartExpr();
        }
        return(res);
    }
}

class ESynchronized : EStat {
    mixin StdImpl!();
    override PStatSynchronized getPartStatement(){
        PStatSynchronized stat = new PStatSynchronized;

        stat.mWith = (cast(EExpr)getChild(0)).getPartExpr();
        stat.mWhat = (cast(EStat)getChild(1)).getPartStatement();
        return(stat);
    }
}

class EAssert : EStat {
    mixin StdImpl!();
    override PStatAssert getPartStatement(){
        PStatAssert stat = new PStatAssert;

        stat.mCond = (cast(EExpr)getChild(0)).getPartExpr();
        if (getChildCount() > 1) {
            stat.mMsg = (cast(EExpr)getChild(1)).getPartExpr();
        }
        return(stat);
    }
}

class EReturn : EStat {
    mixin StdImpl!();
    override PStatReturn getPartStatement(){
        PStatReturn stat = new PStatReturn;

        if (getChildCount() > 0) {
            stat.mValue = (cast(EExpr)getChild(0)).getPartExpr();
        }
        return(stat);
    }
}


class ELiteralTry : EStat {
    mixin StdImpl!();
    override PStatTry getPartStatement(){
        PStatTry stat = new PStatTry;

        stat.mTodo = (cast(ESList)getChild(0)).getPartStatement();
        ELiteralCatch c = cast(ELiteralCatch)getChild(1);
        while (c !is null) {
            stat.mHandlers ~= c.getPartStatement();
            c = cast(ELiteralCatch)c.getSibling();
        }
        if (ELiteralFinally fin = cast(ELiteralFinally)tryGetChild("LITERAL_finally")) {
            stat.mFinally = fin.getPartStatement();
        }
        return(stat);
    }
}

class ELiteralCatch : EStat {
    mixin StdImpl!();
    override PStatCatch getPartStatement(){
        PStatCatch stat = new PStatCatch;

        stat.mParam = (cast(EParameterDef)getChild(0)).getPartParameterDef();
        stat.mTodo  = (cast(ESList)getChild(1)).getPartStatement();
        return(stat);
    }
}

class ELiteralFinally : EStat {
    mixin StdImpl!();
    override PStatFinally getPartStatement(){
        PStatFinally stat = new PStatFinally;

        stat.mTodo = (cast(ESList)getChild(0)).getPartStatement();
        return(stat);
    }
}

class EStat : JElement {
    mixin StdImpl!();
    abstract PStatement getPartStatement();
}

class ELiteralIf : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        Element[] childs = getChilds();
        EExpr     cond   = cast(EExpr)childs[0];
        assert(cond !is null, childs[0].getName());
        EStat     tcase = cast(EStat)childs[1];
        assert(tcase !is null, childs[1].getName());
        PStatIf   p = new PStatIf;
        p.mCond  = cond.getPartExpr();
        p.mTCase = tcase.getPartStatement();
        if (childs.length > 2) {
            EStat fcase = cast(EStat)childs[2];
            assert(fcase !is null, childs[2].getName());
            p.mFCase = fcase.getPartStatement();
        }
        return(p);
    }
}

class ELiteralFor : EStat {
    mixin StdImpl!();

    override PStatement getPartStatement(){
        Element c = getFirstChild();

        if (c.getName() == "FOR_INIT") {
            PStatFor p = new PStatFor;
            foreach (Element forinitChild; c.getChilds()) {
                if (forinitChild.getName() == "VARIABLE_DEF") {
                    PVarDef vardef = (cast(EVariableDef)forinitChild).getPartVariableDef();
                    if( vardef ){
                        vardef.mInExpression = true;
                        p.mInit_VarDefs ~= vardef;
                    }
                }
                else if (forinitChild.getName() == "ELIST") {
                    foreach( EExpr expr; cast(EExpr[])forinitChild.getChilds() ){
                        assert( expr !is null, getTrace() );
                        p.mInit_Exprs ~= expr.getPartExpr();
                    }
                }
                else {
                    EExpr expr = cast(EExpr)forinitChild;
                    assert( expr !is null, getTrace() );
                    p.mInit_Exprs ~= expr.getPartExpr();
                }
            }
            c = c.getSibling();
            if (EExpr cond = cast(EExpr)c.getFirstChild()) {
                p.mCondition = cond.getPartExpr();
            }
            c = c.getSibling();
            if (EEList elist = cast(EEList)c.getFirstChild()) {
                p.mIterator = elist.getPartEList();
            }
            c = c.getSibling();
            EStat stat = cast(EStat)c;
            assert(stat);
            p.mStat = stat.getPartStatement();

            return(p);
        }
        else { //foreach
            PStatForeach  p             = new PStatForeach;
            Element[]     foreachChilds = c.getChilds();
            EParameterDef pd            = cast(EParameterDef)foreachChilds[0];
            EExpr         ex            = cast(EExpr)foreachChilds[1];
            p.mParam = pd.getPartParameterDef();
            p.mRange = ex.getPartExpr();

            c = c.getSibling();
            EStat stat = cast(EStat)c;
            assert(stat);
            p.mStat = stat.getPartStatement();
            return(p);
        }
    }
}

class ELiteralSwitch : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        PStatSwitch stat = new PStatSwitch;

        stat.mSwitch = (cast(EExpr)getFirstChild()).getPartExpr();
        foreach (ECaseGroup cg; cast(ECaseGroup[])getChilds("CASE_GROUP")) {
            stat.mCaseGroups ~= cg.getPartCaseGroup();
        }
        return(stat);
    }
}

class ECaseGroup : JElement {
    mixin StdImpl!();
    PCaseGroup getPartCaseGroup(){
        PCaseGroup cg = new PCaseGroup;

        foreach (Element e; getChilds()) {
            switch (e.getName()) {
            case "LITERAL_case":
                cg.mCases ~= (cast(EExpr)e.getFirstChild()).getPartExpr();
                break;

            case "LITERAL_default":
                cg.mIsDefault = true;
                break;

            case "SLIST":
                {
                    assert(cg.mTodo is null);
                    PStatList slist = (cast(ESList)e).getPartStatement();
                    slist.mWithoutScope = true;
                    cg.mTodo            = slist;
                }
                break;

            default:
                assert(false);
                break;
            }
        }
        return(cg);
    }
}

class ELiteralBreakContinue : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        if (getName() == "LITERAL_break") {
            PStatBreak stat = new PStatBreak;
            if (getChildCount() > 0) {
                stat.mName = getFirstChild().getAttribute("text");
            }
            return(stat);
        }
        if (getName() == "LITERAL_continue") {
            PStatContinue stat = new PStatContinue;
            if (getChildCount() > 0) {
                stat.mName = getFirstChild().getAttribute("text");
            }
            return(stat);
        }
        assert(false);
    }
}

class ELiteralDo : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        PStatDo stat = new PStatDo;

        stat.mTodo = (cast(EStat)getChild(0)).getPartStatement();
        stat.mCond = (cast(EExpr)getChild(1)).getPartExpr();
        return(stat);
    }
}

class ELiteralWhile : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        PStatWhile stat = new PStatWhile;
        assert( getChildCount == 2 );
        EExpr e = (cast(EExpr)getChild(0));
        assert( e !is null );
        EStat t = (cast(EStat)getChild(1));
        assert( t !is null, getChild(1).toUtf8 );
        stat.mCond = e.getPartExpr();
        stat.mTodo = t.getPartStatement();
        return(stat);
    }
}


class EExprAssign : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        PExprAssign   ex = new PExprAssign;

        EExpression[] childs = cast(EExpression[])getChilds();
        ex.mOp    = getAttribute("text");
        ex.mLExpr = childs[0].getPartExpr();
        ex.mRExpr = childs[1].getPartExpr();
        return(ex);
    }

    PVarInitializer getPartVarInitializer(){
        assert(getChildCount() == 1);
        Element e = getFirstChild();
        switch (e.getName()) {
        case "EXPR":
            return((cast(EExpr)e).getPartVarInitExpr());

        case "ARRAY_INIT":
            return((cast(EArrayInit)e).getPartVarInitArray());

        default:
            assert(false);
            break;
        }
    }
}

class EExprQuestion : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        EExpression[] childs = cast(EExpression[])getChilds();
        PExprQuestion ex     = new PExprQuestion;
        ex.mCond  = childs[0].getPartExpr();
        ex.mTCase = childs[1].getPartExpr();
        ex.mFCase = childs[2].getPartExpr();
        return(ex);
    }
}

class EExprBinary : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        char[] op = getAttribute("text");
        if( op != "instanceof" ){
            EExpression[] childs = cast(EExpression[])getChilds();
            PExprBinary   ex     = new PExprBinary;
            ex.mOp    = op;
            ex.mLExpr = childs[0].getPartExpr();
            ex.mRExpr = childs[1].getPartExpr();
            return(ex);
        }
        else{
            EExpression[] childs = cast(EExpression[])getChilds();
            PExprInstanceof   ex     = new PExprInstanceof;
            ex.mExpr = childs[0].getPartExpr();
            ex.mTypeInst = (cast(EType)childs[1]).getPartTypeInst();
            return(ex);
        }
    }
}

class EExprUnary : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        EExpression child = cast(EExpression)getFirstChild();

        assert(child);
        PExprUnary ex = new PExprUnary;
        ex.mExpr = child.getPartExpr();
        ex.mOp   = getAttribute("text");
        switch (getName()) {
        case "POST_INC":
        case "POST_DEC":
            ex.mPost = true;
            break;

        default:
            break;
        }
        return(ex);
    }
}

class EExprIndexOp : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        Element[]    childs = getChilds();
        EExpression  eref   = cast(EExpression)childs[0];
        EExpr        eidx   = cast(EExpr)childs[1];
        PExprIndexOp ex     = new PExprIndexOp;
        ex.mRef   = eref.getPartExpr();
        ex.mIndex = eidx.getPartExpr();
        return(ex);
    }
}

class ECtorCall : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        if (getName() == "CTOR_CALL") {
            PExprMethodCall expr = new PExprMethodCall;
            expr.mAsStatement = true;
            expr.mName      = "this";
            expr.mTrgExpr   = null;
            expr.mArguments = (cast(EEList)getChild(0)).getPartEList();
            return(expr);
        }
        if (getName() == "SUPER_CTOR_CALL") {
            PExprMethodCall expr = new PExprMethodCall;
            expr.mAsStatement = true;
            expr.mName      = "super";
            expr.mTrgExpr   = null;
            if (getChild(0).getName() == "ELIST") {
                expr.mTrgExpr   = null;
                expr.mArguments = (cast(EEList)getChild(0)).getPartEList();
            }
            else {
                PExprDot dot = new PExprDot;
                expr.mTrgExpr   = (cast(EExpr)getChild(0)).getPartExpr();
                expr.mArguments = (cast(EEList)getChild(1)).getPartEList();
            }
            return(expr);
        }
        assert(false);
    }
}

class EExprMethodCall : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        PExprMethodCall ex    = new PExprMethodCall;
        EExpression     priex = cast(EExpression)getFirstChild();
        EEList          elist = cast(EEList)getChild("ELIST");

        assert(priex !is null, getFirstChild().getName());
        if( priex.getName() == "IDENT" ){
            ex.mName = priex.getAttribute("text");
            ex.mTrgExpr   = null;
        }
        else if( priex.getName() == "DOT" ){
            ex.mTrgExpr = (cast(EExpression)priex.getChild(0)).getPartExpr();
            ex.mName   =  (cast(EIdent)priex.getChild(1)).getAttribute("text");
        }
        else{
            assert( false, priex.getName() );
        }
        ex.mArguments = elist.getPartEList();
        return(ex);
    }
}

class EExprTypeCast : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        PExprTypecast ex   = new PExprTypecast;
        PExpr         expr = (cast(EExpression)getChild(1)).getPartExpr();
        PTypeInst     ti   = (cast(EType)getChild(0)).getPartTypeInst();

        ex.mTypeInst = ti;
        ex.mExpr     = expr;
        return(ex);
    }
}

class EExprNew : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        Element  c = getFirstChild();

        if (c.getName() == "TYPE_ARGUMENTS") {
            c = c.getSibling();
        }
        PTypeRef tr = (cast(JElement)c).getTypeRef();
        if (hasChild("ARRAY_DECLARATOR")) {
            PExprNewArray ex = new PExprNewArray;
            ex.mTypeRef    = tr;
            ex.mArrayDecls = (cast(ENewArrayDeclarator)getChild("ARRAY_DECLARATOR")).getPartArrayDecls();
            if (hasChild("ARRAY_INIT")) {
                ex.mInitializer = (cast(EArrayInit)getChild("ARRAY_INIT")).getPartVarInitArray();
            }
            return(ex);
        }
        else if (hasChild("OBJBLOCK")) {
            PExprNewAnon ex = new PExprNewAnon;
            ex.mTypeRef   = tr;
            ex.mArguments = (cast(EEList)getChild("ELIST")).getPartEList();
            EObjBlock objBlock = cast(EObjBlock)getChild("OBJBLOCK");
            PClassDef classDef = new PClassDef( currentModule );
            classDef.mModifiers = new PModifiers;
            gAnonymousClassId++;
            classDef.mName = Layouter( "AnonymousClass_ID{0}", gAnonymousClassId );
            objBlock.fillPartClassDef(classDef);
            ex.mClassDef = classDef;
            return(ex);
        }
        else {
            PExprNew ex = new PExprNew;
            ex.mTypeRef   = tr;
            ex.mArguments = (cast(EEList)getChild("ELIST")).getPartEList();
            return(ex);
        }
    }
}

class EArrayDeclarator : JElement {
    mixin StdImpl!();
}

class ENewArrayDeclarator : JElement {
    mixin StdImpl!();
    PArrayDecl[] getPartArrayDecls(){
        PArrayDecl[] res;
        Element      cur = this;
        while (cur) {
            PArrayDecl d = new PArrayDecl;
            Element child = cur.getFirstChild();
            if ( child !is null && child.getName() == "ARRAY_DECLARATOR" ) {
                child = child.getSibling();
            }
            if ( child !is null ) {
                d.mCount = (cast(EExpr)child).getPartExpr();
            }
            res ~= d;
            cur = cur.tryGetChild("ARRAY_DECLARATOR");
        }
        return(res);
    }
}

class EExprLiteral : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        PExprLiteral ex = new PExprLiteral;

        switch (getName()) {
        case "NUM_INT":
            ex.mType = LiteralType.NUM_INT;
            break;

        case "NUM_FLOAT":
            ex.mType = LiteralType.NUM_FLOAT;
            break;

        case "NUM_DOUBLE":
            ex.mType = LiteralType.NUM_DOUBLE;
            break;

        case "NUM_LONG":
            ex.mType = LiteralType.NUM_LONG;
            break;

        case "CHAR_LITERAL":
            ex.mType = LiteralType.CHAR_LITERAL;
            break;

        case "STRING_LITERAL":
            ex.mType = LiteralType.STRING_LITERAL;
            break;

        case "LITERAL_true":
            ex.mType = LiteralType.LITERAL_true;
            break;

        case "LITERAL_false":
            ex.mType = LiteralType.LITERAL_false;
            break;

        case "LITERAL_null":
            ex.mType = LiteralType.LITERAL_null;
            break;

        case "LITERAL_class":
            ex.mType = LiteralType.LITERAL_class;
            break;

        default:
            assert(false, getName());
            break;
        }
        ex.mText = getAttribute("text");
        return(ex);
    }
}

class EExprLiteralSuper : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        PExprLiteral ex = new PExprLiteral;

        ex.mType = LiteralType.LITERAL_super;
        ex.mText = "super";
        return(ex);
    }
}

class EExprLiteralThrow : EStat {
    mixin StdImpl!();
    override PStatement getPartStatement(){
        PStatThrow ex = new PStatThrow;

        ex.mExpr = (cast(EExpr)getFirstChild()).getPartExpr();
        return(ex);
    }
}

class EExprLiteralThis : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        PExprLiteral ex = new PExprLiteral;

        ex.mType = LiteralType.LITERAL_this;
        ex.mText = "this";
        return(ex);
    }
}

class ELiteralBuildinType : EExpression {
    mixin StdImpl!();

    override PExpr getPartExpr(){
        PExprTypeInst p = new PExprTypeInst;
        switch( getName() ){
        case "LITERAL_void":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeVoid, 0, false );
            break;
        case "LITERAL_byte":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeByte, 0, false );
            break;
        case "LITERAL_short":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeShort, 0, false );
            break;
        case "LITERAL_int":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeInt, 0, false );
            break;
        case "LITERAL_float":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeFloat, 0, false );
            break;
        case "LITERAL_long":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeLong, 0, false );
            break;
        case "LITERAL_double":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeDouble, 0, false );
            break;
        case "LITERAL_char":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeChar, 0, false );
            break;
        case "LITERAL_boolean":
            p.mResolvedTypeInst = new PTypeInst( gBuildinTypeBoolean, 0, false );
            break;
        }
        return(p);
    }
}

class EIdent : EExpression {
    mixin StdImpl!();

    override PExpr getPartExpr(){
        PExprIdent p = new PExprIdent;

        p.mName = getAttrText();
        return(p);
    }
}

class EDot : EExpression {
    mixin StdImpl!();
    override PExpr getPartExpr(){
        PExprDot  p = new PExprDot;

        Element[] childs = getChilds();
        if (childs.length == 3 && childs[1].getName() == "TYPE_ARGUMENTS") {
            p.mLExpr = (cast(EExpression)childs[0]).getPartExpr();
            p.mRExpr = (cast(EExpression)childs[2]).getPartExpr();
        }
        else {
            p.mLExpr = (cast(EExpression)childs[0]).getPartExpr();
            p.mRExpr = (cast(EExpression)childs[1]).getPartExpr();
        }
        return(p);
    }
}



class Ident {
    char[][] mIdents;
    char[]   getJoined(){
        char[] res;
        bool   first = true;
        foreach ( s; mIdents) {
            if (!first) {
                res ~= '.';
            }
            res ~= s;
            first = false;
        }
        return(res);
    }
}
class IdentStar : Ident {
    bool   mStar;
    char[] getJoinedStar(){
        if (mStar) {
            return(super.getJoined() ~ ".*");
        }
        else {
            return(super.getJoined());
        }
    }
}

Ident makeIdentifier(Element e){
    Ident i = new Ident();

    if (e.getName() == "DOT") {
        for (Element c = e.getFirstChild; c !is null; c = c.getSibling()) {
            Ident ci = makeIdentifier(c);
            foreach ( s; ci.mIdents) {
                i.mIdents ~= s;
            }
        }
    }
    else if (e.getName() == "IDENT") {
        char[]  ident = escapeKeyword(e.getAttribute("text"));
        Element ta    = e.getSibling();
        i.mIdents ~= ident;
    }
    else if (e.getName() == "TYPE_ARGUMENTS") {
        // handles above
    }
    else {
        Stdout.formatln("unknown element {0} {1}", e.getName(), e.getString());
        assert(false);
    }
    return(i);
}

IdentStar makeIdentifierStar(Element e){
    IdentStar i = new IdentStar();

    if (e.getName() == "DOT") {
        for (Element c = e.getFirstChild; c !is null; c = c.getSibling()) {
            IdentStar ci = makeIdentifierStar(c);
            i.mIdents ~= ci.mIdents;
            if (ci.mStar) {
                i.mStar = true;
            }
        }
    }
    else if (e.getName() == "IDENT") {
        i.mIdents ~= (cast(JElement)e).getAttrText();
    }
    else if (e.getName() == "STAR") {
        i.mStar = true;
    }
    else {
        assert(false);
    }
    return(i);
}


/**
 * escape D keywords, which are not keywords in Java.
 */
char[]           escapeKeyword(const(char)[] aIdent){
    switch (aIdent) {
    case "abstract":
    case "alias":
    case "align":
    case "asm":
    case "assert":
    case "auto":
    case "body":
    case "bool":
    case "break":
    case "byte":
    case "case":
    case "cast":
    case "catch":
    case "cdouble":
    case "cent":
    case "cfloat":
    case "char":
    case "class":
    case "const":
    case "continue":
    case "creal":
    case "dchar":
    case "debug":
    case "default":
    case "delegate":
    case "delete":
    case "deprecated":
    case "do":
    case "double":
    case "else":
    case "enum":
    case "export":
    case "extern":
    case "false":
    case "final":
    case "finally":
    case "float":
    case "for":
    case "foreach":
    case "function":
    case "goto":
    case "idouble":
    case "if":
    case "ifloat":
    case "import":
    case "in":
    case "inout":
    case "int":
    case "interface":
    case "invariant":
    case "ireal":
    case "is":
    case "lazy":
    case "long":
    case "mixin":
    case "module":
    case "new":
    case "null":
    case "out":
    case "override":
    case "package":
    case "pragma":
    case "private":
    case "protected":
    case "public":
    case "real":
    case "return":
    case "scope":
    case "short":
    case "static":
    case "struct":
    case "super":
    case "switch":
    case "synchronized":
    case "template":
    case "this":
    case "throw":
    case "true":
    case "try":
    case "typedef":
    case "typeid":
    case "typeof":
    case "ubyte":
    case "ucent":
    case "uint":
    case "ulong":
    case "union":
    case "unittest":
    case "ushort":
    case "version":
    case "void":
    case "volatile":
    case "wchar":
    case "while":
    case "with":
        // standard properties
    case "sizeof":
    case "mangleof":
        return(aIdent ~ "_ESCAPE");

    default:
        return(aIdent);
    }
}

