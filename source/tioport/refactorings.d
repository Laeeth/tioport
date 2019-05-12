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
module tioport.refactorings;

import tioport.parts;
import tioport.partvisitor;

import             Integer =   tango.text.convert.Integer;
import             tango.text.Util : locatePattern, substitute;
import               tango.io.Stdout;
import               tango.util.container.HashSet;
//import               tango.util.container.TreeMap;
import tango.util.container.HashMap;
alias TreeMap = HashMap;
import tioport.utils;

//version = DEBUG_IMPORTS;

public void refactoreStage1( bool writeInternals ){
    PPackage root = getPackageRoot();

    packJava = root.findChildPackage("java");
    packJavaLang = packJava.findChildPackage("lang");
    assert(packJavaLang !is null);

    createBaseObjects( writeInternals );

    getPackageRoot().accept(new BaseFixer());
}

public void refactoreStage2(){
    getPackageRoot().accept(new MethodListMakerFixer());
}

public PPackage      packJava;
public PPackage      packJavaLang;
public PInterfaceDef gIJObject;
public PModule       gModDObject;
public PModule       gModIntern;
public PClassDef     gDObject;
public PClassDef     gJObjectImpl;
public PClassDef     gClsJavaLangClass;

public PClassDef     gJArrayBoolean;
public PClassDef     gJArrayByte;
public PClassDef     gJArrayShort;
public PClassDef     gJArrayInt;
public PClassDef     gJArrayLong;
public PClassDef     gJArrayFloat;
public PClassDef     gJArrayDouble;
public PClassDef     gJArrayChar;
public PClassDef     gJArrayJObject;
PModule gModJArray;
public PMethodDef    gFncArrayInstanceOfBoolean;
public PMethodDef    gFncArrayInstanceOfByte;
public PMethodDef    gFncArrayInstanceOfShort;
public PMethodDef    gFncArrayInstanceOfInt;
public PMethodDef    gFncArrayInstanceOfLong;
public PMethodDef    gFncArrayInstanceOfFloat;
public PMethodDef    gFncArrayInstanceOfDouble;
public PMethodDef    gFncArrayInstanceOfChar;
public PMethodDef    gFncArrayInstanceOfJObject;

public PMethodDef    gFncEvalOrderedOrI;
public PMethodDef    gFncEvalOrderedOrL;
public PMethodDef    gFncEvalOrderedAndI;
public PMethodDef    gFncEvalOrderedAndL;
public PMethodDef    gFncEvalOrderedXorI;
public PMethodDef    gFncEvalOrderedXorL;

public PMethodDef    gFncInternJniPtrCast;
public PClassDef     gClsTypeInfo;
public PFuncTypeDef  gFncTypeNewInstance;
public PMethodDef    gFncJavaLangSystemArraycopy;
public PMethodDef    gFncJavaLangClassGetClassObject;
public PMethodDef    gFncClassInfo;

public PMethodDef    gFncDHConvertJ2D;
public PMethodDef    gFncDHConvertD2J;

bool[ PMethodDef ] indexFnc;

public void refactoreStage3(PModule aStaticCtorMod){
    renameModule(packJavaLang.findChildModule("Object"), "JObjectImpl");
    renameModule(packJavaLang.findChildModule("Exception"), "JException");
    renameModule(packJavaLang.findChildModule("Thread"), "JThread");
    getPackageRoot().findChildPackage("java").mName = "dejavu";

    gBuildinTypeBoolean.mName = "bool";
    gBuildinTypeChar.mName    = "wchar";

    gFncInternJniPtrCast             = new PMethodDef;
    gFncInternJniPtrCast.mModifiers  = new PModifiers;
    gFncInternJniPtrCast.mName       = "jniPtrCast";
    gFncInternJniPtrCast.mReturnType = new PTypeInst(gBuildinTypePtr, 0, true);

    gModIntern = packJava.findChildModule("Intern");
    gModIntern.mModuleMethods ~= gFncInternJniPtrCast;

    gModJArray = packJavaLang.findChildModule("JArray");

    PClassDef createJArrayClassDef( char[] aName, PTypeDef td, bool withClassInfo ){
        PClassDef res = new PClassDef( gModJArray );
        res.mModifiers = new PModifiers;
        res.mName      = "JArray" ~ aName;
        {
            PMethodDef mth = res.createMethod( "createSimple" );
            mth.mModifiers.mStatic = true;
            if( withClassInfo ){
                mth.mParams ~= new PParameterDef( gModJArray, "aCi", new PTypeInst( gClsTypeInfo, 0, true ) );
            }
            mth.mParams ~= new PParameterDef( gModJArray, "aDim", new PTypeInst( gBuildinTypeInt, 0, true ) );
            mth.mReturnType = new PTypeInst( res, 0, true );
            res.mMethods ~= mth;
        }
        {
            PMethodDef mth = res.createMethod( "createRectangular" );
            mth.mModifiers.mStatic = true;
            if( withClassInfo ){
                mth.mParams ~= new PParameterDef( gModJArray, "aCi", new PTypeInst( gClsTypeInfo, 0, true ) );
            }
            mth.mParams ~= new PParameterDef( gModJArray, "aDim", new PTypeInst( gBuildinTypeInt, 0, true ) );
            {
                auto pd = new PParameterDef( gModJArray, "aSizes", new PTypeInst( gBuildinTypeInt, 0, true ) );
                pd.mIsVariableLength = true;
                mth.mParams ~= pd;
            }
            mth.mReturnType = new PTypeInst( gJArrayJObject, 0, true );
            res.mMethods ~= mth;
        }
        {
            PMethodDef mth = res.createMethod( "createSimpleFromLiteral" );
            mth.mModifiers.mStatic = true;
            if( withClassInfo ){
                mth.mParams ~= new PParameterDef( gModJArray, "aCi", new PTypeInst( gClsTypeInfo, 0, true ) );
                mth.mParams ~= new PParameterDef( gModJArray, "aDims", new PTypeInst( gBuildinTypeInt, 0, true ) );
            }
            {
                auto pd = new PParameterDef( gModJArray, "aDims", new PTypeInst( td, 0, true ) );
                pd.mIsVariableLength = true;
                mth.mParams ~= pd;
            }
            mth.mReturnType = new PTypeInst( res, 0, true );
            res.mMethods ~= mth;
        }
        {
            PMethodDef mth = res.createMethod( "index" );
            mth.mParams ~= new PParameterDef( gModJArray, "index", new PTypeInst( gBuildinTypeInt, 0, true ) );
            mth.mReturnType = new PTypeInst( td, 0, true );
            res.mMethods ~= mth;
            indexFnc[ mth ] = true;
        }
        PMethodDef createAssignOpMethod( char[] name ){
            PMethodDef mth = res.createMethod( "indexAssign" ~ name );
            mth.mParams ~= new PParameterDef( gModJArray, "val", new PTypeInst( td, 0, true ) );
            mth.mParams ~= new PParameterDef( gModJArray, "index", new PTypeInst( gBuildinTypeInt, 0, true ) );
            mth.mReturnType = new PTypeInst( td, 0, true );
            return mth;
        }
        res.mMethods ~= createAssignOpMethod( "" );

        if( withClassInfo ){
            return res;
        }

        res.mMethods ~= createAssignOpMethod( "Plus" );
        res.mMethods ~= createAssignOpMethod( "Minus" );
        res.mMethods ~= createAssignOpMethod( "Mul" );
        res.mMethods ~= createAssignOpMethod( "Div" );
        res.mMethods ~= createAssignOpMethod( "Modulo" );
        res.mMethods ~= createAssignOpMethod( "Or" );
        res.mMethods ~= createAssignOpMethod( "Xor" );
        res.mMethods ~= createAssignOpMethod( "And" );
        res.mMethods ~= createAssignOpMethod( "ShiftLeft" );
        res.mMethods ~= createAssignOpMethod( "ShiftRight" );

        PMethodDef createAssignUnaryMethod( char[] name ){
            PMethodDef mth = res.createMethod( "indexAssign" ~ name );
            mth.mParams ~= new PParameterDef( gModJArray, "index", new PTypeInst( gBuildinTypeInt, 0, true ) );
            mth.mReturnType = new PTypeInst( td, 0, true );
            return mth;
        }
        res.mMethods ~= createAssignUnaryMethod( "Decr" );
        res.mMethods ~= createAssignUnaryMethod( "PostDecr" );
        res.mMethods ~= createAssignUnaryMethod( "Incr" );
        res.mMethods ~= createAssignUnaryMethod( "PostIncr" );

        PMethodDef createEvalOrdedMeth( char[] name, PTypeDef td ){
            PMethodDef mth = res.createMethod( name );
            mth.mParams ~= new PParameterDef( gModIntern, "a", new PTypeInst( td, 0, true ) );
            mth.mParams ~= new PParameterDef( gModIntern, "b", new PTypeInst( td, 0, true ) );
            mth.mReturnType = new PTypeInst( td, 0, true );
            mth.mModuleFunc = gModIntern;
            gModIntern.mModuleMethods ~= mth;
            return mth;
        }
        gFncEvalOrderedOrI  = createEvalOrdedMeth( "OrI", gBuildinTypeInt );
        gFncEvalOrderedOrL  = createEvalOrdedMeth( "OrL", gBuildinTypeLong );
        gFncEvalOrderedXorI = createEvalOrdedMeth( "XorI", gBuildinTypeInt );
        gFncEvalOrderedXorL = createEvalOrdedMeth( "XorL", gBuildinTypeLong );
        gFncEvalOrderedAndI = createEvalOrdedMeth( "AndI", gBuildinTypeInt );
        gFncEvalOrderedAndL = createEvalOrdedMeth( "AndL", gBuildinTypeLong );
        // for the others, there are more methods to add.
        return res;
    }

    gJArrayJObject = createJArrayClassDef( "JObject", gIJObject          , true  );
    gJArrayBoolean = createJArrayClassDef( "Boolean", gBuildinTypeBoolean, false );
    gJArrayByte    = createJArrayClassDef( "Byte"   , gBuildinTypeByte   , false );
    gJArrayShort   = createJArrayClassDef( "Short"  , gBuildinTypeShort  , false );
    gJArrayInt     = createJArrayClassDef( "Int"    , gBuildinTypeInt    , false );
    gJArrayLong    = createJArrayClassDef( "Long"   , gBuildinTypeLong   , false );
    gJArrayFloat   = createJArrayClassDef( "Float"  , gBuildinTypeFloat  , false );
    gJArrayDouble  = createJArrayClassDef( "Double" , gBuildinTypeDouble , false );
    gJArrayChar    = createJArrayClassDef( "Char"   , gBuildinTypeChar   , false );

    PMethodDef createJArrayInstanceOf( char[] aName, bool withClassInfo ){
        PMethodDef res = gModJArray.createMethod( "arrayInstanceOf" ~ aName );
        res.mParams ~= new PParameterDef( gModJArray, "aObj", new PTypeInst( gIJObject, 0, true ) );
        res.mParams ~= new PParameterDef( gModJArray, "aDim", new PTypeInst( gBuildinTypeInt, 0, true ) );
        if( withClassInfo ){
            res.mParams ~= new PParameterDef( gModJArray, "aCi", new PTypeInst( gClsTypeInfo, 0, true ) );
        }
        res.mReturnType = new PTypeInst( gBuildinTypeBoolean, 0, true );
        res.mModuleFunc = gModIntern;
        gModIntern.mModuleMethods ~= res;
        return res;
    }

    gFncArrayInstanceOfBoolean = createJArrayInstanceOf( "Boolean", false );
    gFncArrayInstanceOfByte    = createJArrayInstanceOf( "Byte"   , false );
    gFncArrayInstanceOfShort   = createJArrayInstanceOf( "Short"  , false );
    gFncArrayInstanceOfInt     = createJArrayInstanceOf( "Int"    , false );
    gFncArrayInstanceOfLong    = createJArrayInstanceOf( "Long"   , false );
    gFncArrayInstanceOfFloat   = createJArrayInstanceOf( "Float"  , false );
    gFncArrayInstanceOfDouble  = createJArrayInstanceOf( "Double" , false );
    gFncArrayInstanceOfChar    = createJArrayInstanceOf( "Char"   , false );
    gFncArrayInstanceOfJObject = createJArrayInstanceOf( "JObject", true  );

    {
        gFncDHConvertD2J = gModIntern.createMethod( "convertD2J" );
        gFncDHConvertD2J.mParams ~= new PParameterDef( gModIntern, "a", new PTypeInst( gIJObject, 0, true ) );
        gFncDHConvertD2J.mReturnType = new PTypeInst( gIJObject, 0, true );
        gFncDHConvertD2J.mModuleFunc = gModIntern;
        gModIntern.mModuleMethods ~= gFncDHConvertD2J;
    }
    {
        gFncDHConvertJ2D = gModIntern.createMethod( "convertJ2D" );
        gFncDHConvertJ2D.mParams ~= new PParameterDef( gModIntern, "a", new PTypeInst( gIJObject, 0, true ) );
        gFncDHConvertJ2D.mReturnType = new PTypeInst( gIJObject, 0, true );
        gFncDHConvertJ2D.mModuleFunc = gModIntern;
        gModIntern.mModuleMethods ~= gFncDHConvertJ2D;
    }

    Stdout.formatln( "JObjectImplToJObjectFixer" );
    getPackageRoot().accept(new JObjectImplToJObjectFixer());
    Stdout.formatln( "ArrayFixer" );
    getPackageRoot().accept(new ArrayFixer());
    Stdout.formatln( "ArrayRefFixer" );
    getPackageRoot().accept(new ArrayRefFixer());
    Stdout.formatln( "IdentifierEscaperFixer" );
    getPackageRoot().accept(new IdentifierEscaperFixer());
    Stdout.formatln( "ImportJavaLangFixer" );
    getPackageRoot().accept(new ImportJavaLangFixer());
    Stdout.formatln( "ToStringFixer" );
    getPackageRoot().accept(new ToStringFixer());
    Stdout.formatln( "InitFixer" );
    getPackageRoot().accept(new InitFixer());
    Stdout.formatln( "SwitchFixer" );
    getPackageRoot().accept(new SwitchFixer());
    Stdout.formatln( "StubMissingReturnFixer" );
    getPackageRoot().accept(new StubMissingReturnFixer());
    Stdout.formatln( "InnerClassThisCastFixer" );
    getPackageRoot().accept(new InnerClassThisCastFixer());
    Stdout.formatln( "ClassObjectPropertyFixer" );
    getPackageRoot().accept(new ClassObjectPropertyFixer());
    Stdout.formatln( "AnonymousClassFixer" );
    getPackageRoot().accept(new AnonymousClassFixer());
    Stdout.formatln( "PullinDerivedMethodsFixer" );
    getPackageRoot().accept(new PullinDerivedMethodsFixer());
    Stdout.formatln( "UniqueFieldAndMethodsFixer" );
    getPackageRoot().accept(new UniqueFieldAndMethodsFixer());
    Stdout.formatln( "RenameShadowingVarsFixer" );
    getPackageRoot().accept(new RenameShadowingVarsFixer());
    Stdout.formatln( "FinallyBlockFixer" );
    getPackageRoot().accept(new FinallyBlockFixer());
    Stdout.formatln( "EvalOrderFixer" );
    getPackageRoot().accept(new EvalOrderFixer());
    Stdout.formatln( "NativeDelegationFixer" );
    getPackageRoot().accept(new NativeDelegationFixer());
    Stdout.formatln( "ModifierFixer" );
    getPackageRoot().accept(new ModifierFixer());
    Stdout.formatln( "ClassRegistrationFixer" );
    getPackageRoot().accept(new ClassRegistrationFixer());
    Stdout.formatln( "StaticCtorFixer" );
    getPackageRoot().accept(new StaticCtorFixer(aStaticCtorMod));
    Stdout.formatln( "ReimplementIfaceFixer" );
    getPackageRoot().accept(new ReimplementIfaceFixer());

    Stdout.formatln( "AssignTypesFixer" );
    getPackageRoot().accept(new AssignTypesFixer());
    Stdout.formatln( "RemoveStatmentCastsFixer" );
    getPackageRoot().accept(new RemoveStatmentCastsFixer());
    Stdout.formatln( "DHelperFixer" );
    getPackageRoot().accept(new DHelperFixer());
    Stdout.formatln( "ModuleInitFixer" );
    getPackageRoot().accept(new ModuleInitFixer());
    Stdout.formatln( "ImportOnlyNeededFixer" );
    getPackageRoot().accept(new ImportOnlyNeededFixer());
}

private:

void renameModule(PModule aModule, char[] aNewName){
    PTypeDef td = aModule.findChildTypeDef(aModule.mName);

    td.mName      = aNewName.dup;
    aModule.mName = aNewName.dup;
}
public void createBaseObjects( bool writeInternals ){
    PModule modJObject = packJavaLang.createModule("JObject");
    gModDObject = getPackageRoot().createModule( "object" );
    gModDObject.mIsNowrite = true;

    gIJObject                        = new PInterfaceDef(modJObject);
    gIJObject.mModifiers             = new PModifiers;
    gIJObject.mModifiers.mProtection = Protection.PUBLIC;
    gIJObject.mName                  = "JObject";
    modJObject.mTypeDefs ~= gIJObject;
    modJObject.mIsNowrite = !writeInternals;

    PModule modObject = packJavaLang.findChildModule("Object");
    assert(modObject !is null, "cannot load 'Object'");
    gJObjectImpl = cast(PClassDef)modObject.findChildTypeDef("Object");
    // JObject as an interface of JObjectImpl
    PTypeRef tr = new PTypeRef;
    tr.mResolvedTypeDef = gIJObject;
    gJObjectImpl.mSuperIfaces ~= tr;

    // clone method
    foreach (PMethodDef mth; gJObjectImpl.mMethods) {
        gIJObject.mMethods ~= mth.cloneMethodDefDeclaration();
    }
    PModule modSystem = packJavaLang.findChildModule("System");
    assert(modSystem !is null, "cannot load 'System'");
    PClassDef s = cast(PClassDef)modSystem.findChildTypeDef("System");
    foreach (PMethodDef m; s.mMethods) {
        if (m.mName == "arraycopy") {
            gFncJavaLangSystemArraycopy = m;
        }
    }
    assert(gFncJavaLangSystemArraycopy !is null);


    PModule modClass = packJavaLang.findChildModule("Class");
    assert(modClass !is null, "cannot load 'Class'");
    gClsJavaLangClass = cast(PClassDef)modClass.findChildTypeDef("Class");
    assert(gClsJavaLangClass !is null);

    foreach (PMethodDef m; gClsJavaLangClass.mMethods) {
        if (m.mName == "getClassObject") {
            gFncJavaLangClassGetClassObject = m;
        }
    }
    assert(gFncJavaLangClassGetClassObject !is null);

    gBuildinTypeVoid.mClass    = createClassFieldDef(gJavaIntern);
    gBuildinTypeBoolean.mClass = createClassFieldDef(gJavaIntern);
    gBuildinTypeChar.mClass    = createClassFieldDef(gJavaIntern);
    gBuildinTypeByte.mClass    = createClassFieldDef(gJavaIntern);
    gBuildinTypeShort.mClass   = createClassFieldDef(gJavaIntern);
    gBuildinTypeInt.mClass     = createClassFieldDef(gJavaIntern);
    gBuildinTypeLong.mClass    = createClassFieldDef(gJavaIntern);
    gBuildinTypeFloat.mClass   = createClassFieldDef(gJavaIntern);
    gBuildinTypeDouble.mClass  = createClassFieldDef(gJavaIntern);
    gBuildinTypeNull.mClass    = createClassFieldDef(gJavaIntern);

    gDObject            = new PObjectClassDef(gModDObject);
    gDObject.mModifiers = new PModifiers;
    gDObject.mName      = "Object";

    gClsTypeInfo            = new PClassDef(gJavaIntern);
    gClsTypeInfo.mModifiers = new PModifiers;
    gClsTypeInfo.mName      = "ClassInfo";
    getPackageRoot().mGlobalTypeDefs ~= gClsTypeInfo;

    gFncTypeNewInstance = new PFuncTypeDef( gClsJavaLangClass.mModule );
    gFncTypeNewInstance.mReturnType = new PTypeInst( gIJObject, 0, true );
    gFncTypeNewInstance.mParams = null;

    gFncClassInfo             = new PMethodDef;
    gFncClassInfo.mName       = "classinfo";
    gFncClassInfo.mReturnType = new PTypeInst(gClsTypeInfo, 0, false);


    getPackageRoot().mGlobalTypeDefs ~= gClsTypeInfo;
}

public bool isArrayTypeDef( PTypeDef td ){
    if( td is gJArrayBoolean ){ return true; }
    if( td is gJArrayByte    ){ return true; }
    if( td is gJArrayShort   ){ return true; }
    if( td is gJArrayInt     ){ return true; }
    if( td is gJArrayLong    ){ return true; }
    if( td is gJArrayFloat   ){ return true; }
    if( td is gJArrayDouble  ){ return true; }
    if( td is gJArrayChar    ){ return true; }
    if( td is gJArrayJObject ){ return true; }
    return false;
}

PMethodDef fncCastObjectToArray;
PMethodDef fncCastArrayToObject;

char[] getMangledType( PTypeInst ti ){
    char[] res;
    PTypeInst cur = ti;
    while( cur.mTypeRef.mGenericArgs.length == 1 && isArrayType( cur.mTypeRef.mResolvedTypeDef ) ){
        cur = cur.mTypeRef.mGenericArgs[0];
        res ~= "[";
    }
    res ~= cur.mTypeRef.mangledType();
    return res;
}

PExpr makeLiteralBool( bool aValue ){
    PExprLiteral e = new PExprLiteral();
    e.mType = aValue ? LiteralType.LITERAL_true : LiteralType.LITERAL_false;
    e.mText = aValue ? "true" : "false";
    e.mResolvedTypeInst = new PTypeInst( gBuildinTypeBoolean, 0, true );
    return e;
}
PExpr makeLiteralNull(){
    PExprLiteral e = new PExprLiteral();
    e.mType = LiteralType.LITERAL_null;
    e.mText = "null";
    e.mResolvedTypeInst = new PTypeInst( gBuildinTypeNull, 0, true );
    return e;
}
PExpr makeLiteralIntegerHex( int aValue ){
    PExprLiteral e = new PExprLiteral();
    e.mType = LiteralType.NUM_INT;
    e.mText = "0x" ~ Integer.toUtf8( aValue, Integer.Style.Hex );
    e.mResolvedTypeInst = new PTypeInst( gBuildinTypeInt, 0, true );
    return e;
}

PExpr makeString( char[] str ){
    PExprLiteral e = new PExprLiteral();
    e.mType = LiteralType.LITERAL_null;
    e.mText = "\"" ~ str ~ "\"";
    e.mResolvedTypeInst = new PTypeInst( gBuildinTypeChar, 1, true );

    PExprNew n = new PExprNew();
    n.mTypeRef                  = new PTypeRef;
    n.mTypeRef.mResolvedTypeDef = gTypeJavaLangString;
    n.mArguments ~= e;
    n.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
    n.resolveCtor();
    return n;
}
PExprMethodCall makeClassInfo( PTypeDef aTd ){
    PExprMethodCall etypeid = new PExprMethodCall;
    etypeid.mResolvedCallable = gFncClassInfo;
    etypeid.mName = gFncClassInfo.mName.dup;
    PExprTypeInst   ecallTrg = new PExprTypeInst;
    ecallTrg.mResolvedTypeInst = new PTypeInst(aTd, 0, false);
    etypeid.mTrgExpr = ecallTrg;
    etypeid.mResolvedTypeInst = new PTypeInst(gClsTypeInfo, 0, false);
    return etypeid;
}

PFieldDef createClassFieldDef(PModule aModule){
    PFieldDef _class = new PFieldDef(aModule);

    _class.mName                               = "class";
    _class.mModifiers                          = new PModifiers;
    _class.mModifiers.mStatic                  = true;
    _class.mTypeInst                           = new PTypeInst;
    _class.mTypeInst.mTypeRef                  = new PTypeRef;
    _class.mTypeInst.mTypeRef.mResolvedTypeDef = gClsJavaLangClass;
    return(_class);
}

PExprTypecast createTypecast( PExpr e, PTypeInst ti ){
    PExprTypecast etcast = new PExprTypecast;
    etcast.mExpr             = e;
    etcast.mTypeInst         = ti.clone();
    etcast.mResolvedTypeInst = etcast.mTypeInst;
    return(etcast);
}

class BaseFixer : PartTraversVisitor {
    PClassDef outerClass;
    override void visit(PClassDef p){
        // if no ctor is define, define a std ctor
        if (p.mCtors.length == 0) {
            PCtor ctor = new PCtor;
            ctor.mModifiers             = new PModifiers;
            ctor.mModifiers.mProtection = Protection.PUBLIC;
            ctor.mStatList              = new PStatList;
            ctor.mName                  = "this";
            p.mCtors ~= ctor;
        }

        assert(gClsJavaLangClass !is null);
        p.mClass = createClassFieldDef(p.mModule);

        if (p is gJObjectImpl) {
            return;
        }

        // if no super class is defined, lets derive from JObjectImpl
        if (p.mSuperClass is null) {
            PTypeRef tr = new PTypeRef;
            tr.mResolvedTypeDef = gJObjectImpl;
            p.mSuperClass       = tr;
        }

        if( outerClass !is null ){
            p.mOuter = new PFieldDef( mModule );
            p.mOuter.mName      = "outer";
            p.mOuter.mModifiers = new PModifiers;
            p.mOuter.mTypeInst  = new PTypeInst( outerClass, 0, true );
        }

        PClassDef bak = outerClass;
        outerClass = p;
        super.visit(p);
        outerClass = bak;
    }

    override void visit(PInterfaceDef p){
        if (p is gIJObject) {
            return;
        }
        if (p.mSuperIfaces.length == 0) {
            PTypeRef tr = new PTypeRef;
            tr.mResolvedTypeDef = gIJObject;
            p.mSuperIfaces ~= tr;
        }
        super.visit(p);
    }
}

/**
  Instead of using JObjectImpl, everything shall use JObject.
  Only exception is "new Object" (not arrays) and Object as a base class.
  */
class JObjectImplToJObjectFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    private void check( inout PTypeDef t ){
        if( t is gJObjectImpl ){
            t = gIJObject;
        }
    }
    override void visit( PExprNewArray p ){
        super.visit( p );

        assert( p !is null );
        assert( p.mTypeRef !is null );
        assert( p.mTypeRef.mResolvedTypeDef !is null );

        check( p.mTypeRef.mResolvedTypeDef );
        check( p.mResolvedTypeInst.mTypeRef.mResolvedTypeDef );
    }

    override void visit( PFieldDef p ){
        super.visit( p );

        assert( p !is null );
        assert( p.mTypeInst !is null );
        assert( p.mTypeInst.mTypeRef !is null );
        assert( p.mTypeInst.mTypeRef.mResolvedTypeDef !is null );

        check( p.mTypeInst.mTypeRef.mResolvedTypeDef );
    }

    override void visit( PLocalVarDef p ){
        super.visit( p );

        assert( p !is null );
        assert( p.mTypeInst !is null );
        assert( p.mTypeInst.mTypeRef !is null );
        assert( p.mTypeInst.mTypeRef.mResolvedTypeDef !is null );

        check( p.mTypeInst.mTypeRef.mResolvedTypeDef );
    }

    override void visit( PParameterDef p ){
        super.visit( p );

        assert( p !is null );
        assert( p.mTypeInst !is null );
        assert( p.mTypeInst.mTypeRef !is null );
        assert( p.mTypeInst.mTypeRef.mResolvedTypeDef !is null );

        check( p.mTypeInst.mTypeRef.mResolvedTypeDef );
    }

    override void visit( PMethodDef p ){
        super.visit( p );

        assert( p !is null );
        assert( p.mReturnType !is null );
        assert( p.mReturnType !is null );
        assert( p.mReturnType.mTypeRef !is null );
        assert( p.mReturnType.mTypeRef.mResolvedTypeDef !is null );

        check( p.mReturnType.mTypeRef.mResolvedTypeDef );
    }
    override void visit( PExprTypecast p ){
        super.visit( p );
        check( p.mResolvedTypeInst.mTypeRef.mResolvedTypeDef );
        check( p.mTypeInst.mTypeRef.mResolvedTypeDef );
    }
}

/**
 * Change all Java arrays into JArrayT objects.
 */
class ArrayFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    override void visit(PVarDef p){
        super.visit(p);
        processTypeInst( p.mTypeInst );
    }
    override void visit(PVarInitExpr p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PLocalVarDef p){
        super.visit(p);
        processTypeInst( p.mTypeInst );
    }
    override void visit(PFieldDef p){
        super.visit(p);
        processTypeInst( p.mTypeInst );
    }
    override void visit(PParameterDef p){
        super.visit(p);
        if( p.mIsVariableLength ){
            p.mTypeInst.mDimensions++;
        }
        processTypeInst( p.mTypeInst );
    }
    override void visit(PMethodDef p){
        super.visit(p);
        processTypeInst( p.mReturnType );
    }

    override void visit(PExprInstanceof p){
        super.visit(p);
        processTypeInst( p.mTypeInst );
    }
    override void visit(PExprMethodCall p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprTypecast p){
        super.visit(p);
        processTypeInst( p.mTypeInst );
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprVarRef p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprIndexOp p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExpr p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprFncRef p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprTypeInst p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprIdent p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprDot p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprQuestion p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprBinary p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprUnary p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprAssign p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }
    override void visit(PExprLiteral p){
        super.visit(p);
        processTypeInst( p.mResolvedTypeInst );
    }

    private void processTypeInst( inout PTypeInst ti ){
        int dim = ti.mDimensions;
        if( dim == 0 ){
            return;
        }
        PTypeInst cpy = ti.clone();
        ti = buildArrayTypeInst( cpy );
    }
}

PTypeInst buildArrayTypeInst( PTypeInst elementTypeInst ){
    if( elementTypeInst.mDimensions == 0 && isArrayTypeDef( elementTypeInst.mTypeRef.mResolvedTypeDef )){
        return elementTypeInst;
    }
    assert( elementTypeInst.mDimensions != 0 );
    PTypeInst elTi = elementTypeInst.clone();
    int dim = elementTypeInst.mDimensions;
    elTi.mDimensions = 0;
    PTypeDef elTd = getArrayClassDef( elTi.mTypeRef.mResolvedTypeDef );

    PTypeInst last = null;
    int i = 0;
    while( i < dim ){
        PTypeInst cur;
        if( i == 0 ){
            PClassDef acd = getArrayClassDef( elTi.mTypeRef.mResolvedTypeDef );
            cur = new PTypeInst( acd, 0, true );
            cur.mTypeRef.mGenericArgs ~= elTi;
        }
        else{
            cur = new PTypeInst( gJArrayJObject, 0, true );
        }

        if( last !is null ){
            cur.mTypeRef.mGenericArgs ~= last;
        }
        last = cur;
        i++;
    }
    return last;
}

class ArrayRefFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    private bool isBasicArrayElementType( PTypeDef aTi ){
        if( aTi is gBuildinTypeBoolean ) return true;
        if( aTi is gBuildinTypeByte    ) return true;
        if( aTi is gBuildinTypeShort   ) return true;
        if( aTi is gBuildinTypeInt     ) return true;
        if( aTi is gBuildinTypeLong    ) return true;
        if( aTi is gBuildinTypeFloat   ) return true;
        if( aTi is gBuildinTypeDouble  ) return true;
        if( aTi is gIJObject           ) return true;
        return false;
    }

    override void visit(PExprUnary p){

        PExprIndexOp ei = cast(PExprIndexOp) p.mExpr;
        char[] name;
        bool   ok = false;
        if( p.mOp == "++" ){
            name = p.mPost ? "indexAssignPostIncr" : "indexAssignIncr";
            ok = true;
        }
        if( p.mOp == "--" ){
            name = p.mPost ? "indexAssignPostDecr" : "indexAssignDecr";
            ok = true;
        }
        if( ei !is null && ok ){

            goVisitPart( ei, ei.mRef   );
            goVisitPart( ei, ei.mIndex );

            PTypeInst     refTypeInst = ei.mRef.mResolvedTypeInst;
            PTypeRef      refTypeRef = refTypeInst.mTypeRef;
            PInterfaceDef refTypeDef  = cast(PInterfaceDef) refTypeRef.mResolvedTypeDef;
            //Stdout.formatln( scopeStackToUtf8 );
            assert( refTypeDef !is null, ei.mRef.mResolvedTypeInst.toUtf8 );
            PMethodDef mth = refTypeDef.findMethod( name );

            PExprMethodCall ecall = new PExprMethodCall();
            ecall.mResolvedCallable = mth;
            ecall.mName = name;
            ecall.mResolvedTypeInst = p.mExpr.mResolvedTypeInst;
            ecall.mTrgExpr = ei.mRef;
            ecall.mArguments ~= ei.mIndex; // index
            ecall.mAsStatement = p.mAsStatement;

            p.mPartParent.exchangeExpr( p, ecall );
        }
        else{
            super.visit(p);
        }
    }
    override void visit(PExprAssign p){

        // special care is needed, because if super.visit(p) is called first,
        // the mLExpr will be replace with the "index" call, but we want in this
        // case the "indexAssign"
        PExprIndexOp ei = cast(PExprIndexOp) p.mLExpr;
        char[] name;
        bool   ok = false;
        switch( p.mOp ){
            case "=":  name = "indexAssign";       ok = true; break;
            case "+=": name = "indexAssignPlus";   ok = true; break;
            case "-=": name = "indexAssignMinus";  ok = true; break;
            case "*=": name = "indexAssignMul";    ok = true; break;
            case "/=": name = "indexAssignDiv";    ok = true; break;
            case "%=": name = "indexAssignModulo"; ok = true; break;
            case "|=": name = "indexAssignOr";     ok = true; break;
            case "^=": name = "indexAssignXor";    ok = true; break;
            case "&=": name = "indexAssignAnd";    ok = true; break;
            case "<<=": name = "indexAssignShiftLeft";  ok = true; break;
            case ">>=": name = "indexAssignShiftRight"; ok = true; break;
            default: ok = false; break;
        }
        if( ei !is null && ok ){

            goVisitPart( ei, ei.mRef   );
            goVisitPart( ei, ei.mIndex );
            goVisitPart( p, p.mRExpr );

            PTypeInst     refTypeInst = ei.mRef.mResolvedTypeInst;
            PTypeRef      refTypeRef = refTypeInst.mTypeRef;
            PInterfaceDef refTypeDef  = cast(PInterfaceDef) refTypeRef.mResolvedTypeDef;
            //Stdout.formatln( scopeStackToUtf8 );
            assert( refTypeDef !is null, ei.mRef.mResolvedTypeInst.toUtf8 );
            PMethodDef mth = refTypeDef.findMethod( name );

            PExprMethodCall ecall = new PExprMethodCall();
            ecall.mResolvedCallable = mth;
            ecall.mName = name;
            ecall.mResolvedTypeInst = p.mLExpr.mResolvedTypeInst;
            ecall.mTrgExpr = ei.mRef;
            ecall.mArguments ~= p.mRExpr; // value
            ecall.mArguments ~= ei.mIndex; // index
            ecall.mAsStatement = p.mAsStatement;

            PExpr res = ecall;

            assert( refTypeRef.mGenericArgs.length <= 1 );

            //if( refTypeRef.mGenericArgs.length == 1 && !isBasicArrayElementType( refTypeRef.mGenericArgs[0].mTypeRef.mResolvedTypeDef ) ){
                PExprTypecast ecast = new PExprTypecast();
                ecast.mExpr             = ecall;
                ecast.mTypeInst         = refTypeRef.mGenericArgs[0].clone();
                ecast.mResolvedTypeInst = ecast.mTypeInst.clone();

                res = ecast;
            //}

            p.mPartParent.exchangeExpr( p, res );
        }
        else{
            super.visit(p);
        }
    }
    override void visit(PExprIndexOp p){
        super.visit(p);

        char[] name = "index";
        PTypeInst     refTypeInst = p.mRef.mResolvedTypeInst;
        PTypeRef      refTypeRef = refTypeInst.mTypeRef;
        PInterfaceDef refTypeDef  = cast(PInterfaceDef) refTypeRef.mResolvedTypeDef;
        assert( refTypeDef !is null, p.mRef.mResolvedTypeInst.toUtf8 );
        //Stdout.formatln( scopeStackToUtf8 );
        //Stdout.formatln( refTypeInst.toUtf8 );
        PMethodDef mth = refTypeDef.findMethod( name );

        PExprMethodCall ecall = new PExprMethodCall();
        ecall.mName = name;
        ecall.mResolvedCallable = mth;
        ecall.mResolvedTypeInst = mth.mReturnType;
        ecall.mArguments ~= p.mIndex;
        ecall.mTrgExpr = p.mRef;
        ecall.mAsStatement = p.mAsStatement;

        PExpr res = ecall;

        assert( refTypeRef.mGenericArgs.length <= 1 );

        if( !p.mAsStatement && refTypeRef.mGenericArgs.length == 1 && !isBasicArrayElementType( refTypeRef.mGenericArgs[0].mTypeRef.mResolvedTypeDef ) ){
            PExprTypecast ecast = new PExprTypecast();
            ecast.mExpr             = ecall;
            ecast.mTypeInst         = refTypeRef.mGenericArgs[0].clone();
            ecast.mResolvedTypeInst = ecast.mTypeInst.clone();

            res = ecast;
        }
        p.mPartParent.exchangeExpr( p, res );
    }
    override void visit(PExprMethodCall p){
        super.visit(p);
        PCtor callable = cast(PCtor)p.mResolvedCallable;
        if( callable is null ){
            return;
        }
        if( callable.mParams.length == 0 ){
            return;
        }
        int paramIdx = callable.mParams.length - 1;
        PParameterDef pd = callable.mParams[ paramIdx ];
        if( !pd.mIsVariableLength ){
            return;
        }

        assert( p.mArguments.length >= paramIdx );

        PExpr[] args = p.mArguments[ paramIdx .. $ ];
        p.mArguments.length = paramIdx +1;

        PClassDef cd = cast(PClassDef)pd.mTypeInst.mTypeRef.mResolvedTypeDef;
        PExprMethodCall ecall = new PExprMethodCall();
        ecall.mResolvedTypeInst = pd.mTypeInst.clone();
        ecall.mResolvedCallable = cd.findMethod( "createSimpleFromLiteral" );
        ecall.mName = ecall.mResolvedCallable.mName.dup;
        {
            PExprTypeInst eti = new PExprTypeInst;
            eti.mResolvedTypeInst = pd.mTypeInst.clone();
            ecall.mTrgExpr = eti;
        }

        if( pd.mTypeInst.mTypeRef.mResolvedTypeDef is gJArrayJObject ){
            ecall.mArguments ~= makeClassInfo( pd.mTypeInst.mTypeRef.mGenericArgs[0].mTypeRef.mResolvedTypeDef );
            ecall.mArguments ~= makeLiteralIntegerHex(1);
        }

        foreach ( PExpr e; args ) {
            ecall.mArguments ~= e;
        }
        p.mArguments[ paramIdx ] = ecall;
    }
}

bool isPrimitiveArrayType( PTypeDef aTi ){
    if( aTi is gJArrayBoolean ) return true;
    if( aTi is gJArrayByte    ) return true;
    if( aTi is gJArrayShort   ) return true;
    if( aTi is gJArrayInt     ) return true;
    if( aTi is gJArrayLong    ) return true;
    if( aTi is gJArrayFloat   ) return true;
    if( aTi is gJArrayDouble  ) return true;
    if( aTi is gJArrayChar    ) return true;
    return false;
}

bool isArrayType( PTypeDef aTi ){
    if( isPrimitiveArrayType( aTi ) ) return true;
    if( aTi is gJArrayJObject ) return true;
    return false;
}

/**
  Fill in the content to the mAccessibleMethods hash.
  */
class MethodListMakerFixer : PartTraversVisitor {
    alias  PartTraversVisitor.visit visit;

    private void addMethod( inout PCtor[][ char[] ] aAccessibleMethods, char[] aName, PCtor aMethod ){
        if( !( aName in aAccessibleMethods )){
            aAccessibleMethods[ aName.dup ] = [ aMethod ];
        }
        else{
            bool found = false;
            PCtor[] availableMthds = aAccessibleMethods[ aName ];
            foreach( PCtor tstMthd; availableMthds ){
                if( tstMthd.hasEqualSignature( aMethod ) ){
                    found = true;
                }
            }
            if( !found ){
                aAccessibleMethods[ aName.dup ] = availableMthds ~ aMethod;
            }
        }
    }

    private void updateInterfaces( PInterfaceDef p ){
        if( p.mAccessibleMethods.length > 0 ){
            return;
        }
        foreach( PMethodDef mth; p.mMethods ){
            addMethod( p.mAccessibleMethods, mth.mName, mth );
        }
        foreach( PTypeRef tr; p.mSuperIfaces ){
            PInterfaceDef id = cast(PInterfaceDef)tr.mResolvedTypeDef;
            assert( id !is null );
            updateInterfaces( id );
            foreach( char[] k; id.mAccessibleMethods.keys ){
                foreach( PCtor mth; id.mAccessibleMethods[ k ] ){
                    addMethod( p.mAccessibleMethods, k, mth );
                }
            }
        }
    }

    private void updateClasses( PClassDef p ){
        assert( p !is null );

        if( p.mAccessibleMethods.length > 0 ){
            return;
        }

        foreach( PMethodDef mth; p.mMethods ){
            addMethod( p.mAccessibleMethods, mth.mName, mth );
        }

        if (p.mSuperClass !is null) {
            assert( p.mSuperClass !is null );
            assert( p.mSuperClass.mResolvedTypeDef !is null );
            PClassDef sc = cast(PClassDef)( p.mSuperClass.mResolvedTypeDef );
            assert( sc !is null );
            updateClasses( sc );
            foreach( char[] k; sc.mAccessibleMethods.keys ){
                foreach( PCtor mth; sc.mAccessibleMethods[ k ] ){
                    addMethod( p.mAccessibleMethods, k, mth );
                }
            }
        }
        foreach( PTypeRef tr; p.mSuperIfaces ){
            PInterfaceDef id = cast(PInterfaceDef)tr.mResolvedTypeDef;
            assert( id !is null );
            updateInterfaces( id );
            foreach( char[] k; id.mAccessibleMethods.keys ){
                foreach( PCtor mth; id.mAccessibleMethods[ k ] ){
                    addMethod( p.mAccessibleMethods, k, mth );
                }
            }
        }
        if( p.mParent !is null ){
            PClassDef oc = cast(PClassDef)p.mParent;
            assert( oc !is null );
            updateClasses( oc );
            foreach( char[] k; oc.mAccessibleMethods.keys ){
                foreach( PCtor mth; oc.mAccessibleMethods[ k ] ){
                    addMethod( p.mAccessibleMethods, k, mth );
                }
            }
        }

        if( "super" in p.mAccessibleMethods ){
            p.mAccessibleMethods.remove( "super" );
        }
        if( "this" in p.mAccessibleMethods ){
            p.mAccessibleMethods[ "super" ] = p.mAccessibleMethods[ "this" ].dup;
            p.mAccessibleMethods.remove( "this" );
        }
        if( p.mCtors.length > 0 ){
            p.mAccessibleMethods[ "this"  ] = p.mCtors.dup;
        }

        //if( p.getFqn() == "org.eclipse.swt.events.TypedEvent.TypedEvent" ){
        //    foreach( char[] k; p.mAccessibleMethods.keys ){
        //        PCtor[] cts = p.mAccessibleMethods[ k ];
        //        foreach( PCtor ct; cts ){
        //            Stdout.formatln( " 1 accessible {} : {} >{}", k, ct.toUtf8, ct.mName );
        //        }
        //    }
        //}
        //if( p.getFqn() == "org.eclipse.swt.custom.BidiSegmentEvent.BidiSegmentEvent" ){
        //    foreach( char[] k; p.mAccessibleMethods.keys ){
        //        PCtor[] cts = p.mAccessibleMethods[ k ];
        //        
        //        foreach( PCtor ct; cts ){
        //            Stdout.formatln( " 2 accessible {} : {} >{} : {}", k, ct.toUtf8, ct.mName, ct.mPartParent.toUtf8 );
        //        }
        //    }
        //}
    }

    override void visit(PInterfaceDef p){
        super.visit(p);
        updateInterfaces( p );
    }

    override void visit(PClassDef p){
        super.visit(p);
        updateClasses( p );
    }

}

class IdentifierEscaperFixer : PartTraversVisitor {
    alias  PartTraversVisitor.visit visit;

    int getTraceLevel(){
        return(1);
    }
    override void visit(PExprIdent p){
        p.mName = escape(p.mName);
        super.visit(p);
    }
    override void visit(PParameterDef p){
        if( p.mName == "length" ){
            p.mName = "length_ESCAPE";
        }
        else{
            p.mName = escape(p.mName).dup;
        }
        super.visit(p);
    }
    override void visit(PVarDef p){
        if( p.mName == "length" ){
            p.mName = "length_ESCAPE";
        }
        else{
            p.mName = escape(p.mName).dup;
        }
        super.visit(p);
    }
    override void visit(PFieldDef p){
        if( p.mName == "length" ) {
            if( p.mModule !is gModJArray ){
                p.mName = "length_ESCAPE";
            }
            else{
                // Set the array length to type "uint", then later a cast will be inserted
                p.mTypeInst = new PTypeInst( gBuildinTypeUInt, 0, true );
            }
        }
        else{
            p.mName = escape(p.mName).dup;
        }
        super.visit(p);
    }
    override void visit(PLocalVarDef p){
        if( p.mName == "length" ){
            p.mName = "length_ESCAPE";
        }
        else{
            p.mName = escape(p.mName).dup;
        }
        super.visit(p);
    }
    override void visit(PMethodDef p){
        p.mName = escape(p.mName).dup;
        super.visit(p);
    }
    override void visit(PStatLabeled p){
        p.mName = escape(p.mName);
        super.visit(p);
    }
    override void visit(PStatBreak p){
        p.mName = escape(p.mName);
        super.visit(p);
    }
    override void visit(PStatContinue p){
        p.mName = escape(p.mName);
        super.visit(p);
    }
    override void visit(PExprLiteral p){
        switch (p.mType) {
        case LiteralType.NUM_FLOAT:
            break;

        case LiteralType.NUM_LONG:
            if (p.mText[$ -1] == 'l') {
                p.mText[$ -1] = 'L';
            }
            break;

        case LiteralType.NUM_DOUBLE:
            if (p.mText[$ -1] == 'd' || p.mText[$ -1] == 'D') {
                p.mText = p.mText[0 .. $ -1];
            }
            break;

        case LiteralType.CHAR_LITERAL:
            if (p.mText[0 .. 3] == "'\\u") {
                p.mText = "0x" ~ p.mText[3 .. $ -1];
            }
            {
                PExprTypecast n = new PExprTypecast();
                n.mTypeInst         = new PTypeInst(gBuildinTypeChar, 0, true);
                n.mExpr             = p;
                n.mResolvedTypeInst = new PTypeInst(gBuildinTypeChar, 0, true);
                p.mPartParent.exchangeExpr(p, n);
            }
            break;

        case LiteralType.STRING_LITERAL:
            {
                PExprNew n = new PExprNew();
                n.mTypeRef                  = new PTypeRef;
                n.mTypeRef.mResolvedTypeDef = gTypeJavaLangString;
                n.mArguments ~= p;
                n.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
                n.resolveCtor();
                p.mPartParent.exchangeExpr(p, n);
            }
            break;

        default:
            break;
        }
        super.visit(p);
    }
    char[] escape(char[] name){
        switch (name) {
        case "alias":
        case "align":
        case "asm":
        case "assert":
        case "auto":
        case "body":
        case "bool":
        case "cast":
        case "cdouble":
        case "classinfo":
        case "cent":
        case "cfloat":
        case "const":
        case "creal":
        case "dchar":
        case "debug":
        case "delegate":
        case "delete":
        case "deprecated":
        case "export":
        case "extern":
        case "foreach":
        case "function":
        case "goto":
        case "idouble":
        case "ifloat":
        case "in":
        case "inout":
        case "invariant":
        case "ireal":
        case "is":
        case "lazy":
        case "macro":
        case "mixin":
        case "module":
        case "out":
        case "override":
        case "pragma":
        case "real":
        case "ref":
        case "scope":
        case "struct":
        case "template":
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
        case "wchar":
        case "while":
        case "with":
        case "sizeof":
        case "mangleof":
            //Stdout.formatln( "escape {0} in {1}", name, mModule.getFqn() );
            return(name ~ "_KEYWORDESCAPE");

        default:
            //Stdout.formatln( "non-escape {0} in {1}", name, mModule.getFqn() );
            return(name);
        }
    }
}

class ImportJavaLangFixer : PartTraversVisitor {
    alias      PartTraversVisitor.visit visit;

    PTypeDef[] mJavaLangImportTypeDefs;
    PTypeDef[] mPackageSiblings;
    int getTraceLevel(){
        return(1);
    }
    this(){
        foreach (PModule m; packJavaLang.mModules) {
            mJavaLangImportTypeDefs ~= m.findChildTypeDef(m.mName);
        }
    }

    override void visit(PRootPackage p){
        mPackageSiblings = null;
        foreach (PModule m; p.mModules) {
            mPackageSiblings ~= m.findChildTypeDef(m.mName);
        }
        super.visit(p);
    }
    override void visit(PPackage p){
        mPackageSiblings = null;
        foreach (PModule m; p.mModules) {
            mPackageSiblings ~= m.findChildTypeDef(m.mName);
        }
        super.visit(p);
    }
    override void visit(PModule p){
        p.mVsibileTypeDefs ~= mJavaLangImportTypeDefs;
        p.mVsibileTypeDefs ~= mPackageSiblings;
    }
}

class NativeDelegationFixer : PartTraversVisitor {
    alias     PartTraversVisitor.visit visit;
    PTypeDef  mCurrentTypeDef;
    PModule   mModule;
    PClassDef  mJniEnv;
    PMethodDef mFncGetJni;

    this(){
        mJniEnv = new PClassDef( gJavaIntern );
        mJniEnv.mName = "JNIenv";
        mFncGetJni = new PMethodDef;
        mFncGetJni.mName = "getJniEnv";
        mFncGetJni.mReturnType = new PTypeInst( mJniEnv, 0, true );
        mFncGetJni.mModifiers.mStatic = true;
        mJniEnv.mMethods ~= mFncGetJni;
        ///gJavaIntern.mModuleMethods ~= mFncGetJni;
    }

    private char[] mangle( char[] str ){
        str = .substitute( str, "[", "|3" );
        str = .substitute( str, ";", "|2" );
        str = .substitute( str, "_", "|1" );
        str = .substitute( str, "|", "_" );
        str = .substitute( str, ".", "_" );
        str = .substitute( str, "/", "_" );
        return str;
    }
    private char[] getMethodCName( PModule aModule, PInterfaceDef aIntf, PMethodDef aMethod ){
        int cnt = 0;
        foreach( PMethodDef mth; aIntf.mMethods ){
            if( mth.mName.length > 0 && mth.mName == aMethod.mName && mth.mModifiers.mNative ){
                cnt++;
            }
        }
        char[] res = "Java_"
            ~ mangle( aModule.getFqn() )
            ~ "_"
            ~ mangle( aMethod.mName );
        if( cnt > 1 ){
            res ~= "__";
            if( aMethod.mParams.length > 0 ){
                foreach( PParameterDef pd; aMethod.mParams ){
                    res ~= mangle( getMangledType( pd.mTypeInst ) );
                }
            }
        }
        return res;
    }

    override void visit(PModule p){
        mModule = p;
        super.visit(p);
    }
    override void visit(PTypeDef p){
        PTypeDef bak = mCurrentTypeDef;

        mCurrentTypeDef = p;
        super.visit(p);
        mCurrentTypeDef = bak;
    }

    override void visit(PInterfaceDef p){
        PTypeDef bak = mCurrentTypeDef;

        mCurrentTypeDef = p;
        super.visit(p);
        mCurrentTypeDef = bak;
    }

    override void visit(PClassDef p){
        PTypeDef bak = mCurrentTypeDef;

        mCurrentTypeDef = p;
        super.visit(p);
        mCurrentTypeDef = bak;
        foreach( PMethodDef mth; p.mMethods ){
            // remove the native from the method itself,
            // it should call the extern stuff in its implementation.
            // do it here, because if it is removed while processing, overloaded methods are not recognized.
            mth.mModifiers.mNative = false;
        }
    }

    override void visit(PMethodDef p){
        super.visit(p);
        if (p.mModifiers.mNative && (p.mStatList is null || p.mStatList.mStats.length == 0)) {

            // Create extern (C) MethodDef on module level with mangled name

            PMethodDef    m = p.cloneMethodDefDeclaration();
            m.mName = getMethodCName( mModule, cast(PInterfaceDef) mCurrentTypeDef, p );
            m.mModifiers.mStatic       = false;
            m.mModifiers.mSynchronized = false;
            m.mModifiers.mFinal        = false;
            mModule.mModuleMethods ~= m;
            m.mStatList = null;

            // make a selfcall, because this can be used for an easier implementation.
            PExprMethodCall ecall = new PExprMethodCall;

            ecall.mName             = m.mName.dup;
            ecall.mResolvedTypeInst = p.mReturnType;
            ecall.mResolvedCallable = m;
            ecall.mTrgExpr          = null;

            PParameterDef[] prependParams;
            // JNIenv
            {
                PParameterDef pd = new PParameterDef(mModule);
                pd.mTypeInst = new PTypeInst( gBuildinTypePtr, 0, true );
                pd.mName = "env";
                prependParams ~= pd;

                PExprMethodCall c = new PExprMethodCall;
                c.mName             = "fncGetJni";

                PExprTypeInst   ecallTrg = new PExprTypeInst;
                ecallTrg.mResolvedTypeInst = new PTypeInst(mJniEnv, 0, false);
                c.mTrgExpr          = ecallTrg;
                c.mResolvedCallable = mFncGetJni;
                c.mResolvedTypeInst = new PTypeInst(gBuildinTypePtr, 0, true);
                ecall.mArguments ~= c;
            }

            // class object or this
            {
                PParameterDef pd = new PParameterDef(mModule);
                pd.mTypeInst = new PTypeInst( gBuildinTypePtr, 0, true );
                prependParams ~= pd;
                if( p.mModifiers.isStatic ){
                    pd.mName = "lpClazz";

                    PExprMethodCall etypeid = new PExprMethodCall;
                    etypeid.mResolvedCallable = gFncClassInfo;
                    PExprTypeInst   ecallTrg = new PExprTypeInst;
                    ecallTrg.mResolvedTypeInst = new PTypeInst(mCurrentTypeDef, 0, false);
                    etypeid.mTrgExpr = ecallTrg;
                    etypeid.mResolvedTypeInst = new PTypeInst(gClsTypeInfo, 0, false);

                    PExprMethodCall ec    = new PExprMethodCall;
                    PExprTypeInst   ecallTrg2 = new PExprTypeInst;
                    ecallTrg2.mResolvedTypeInst = new PTypeInst(gClsJavaLangClass, 0, false);
                    ec.mTrgExpr             = ecallTrg2;
                    ec.mResolvedCallable    = gFncJavaLangClassGetClassObject;
                    ec.mArguments ~= etypeid;
                    ec.mResolvedTypeInst = gFncJavaLangClassGetClassObject.mReturnType;

                    //PExprTypecast cst = new PExprTypecast;
                    //cst.mExpr = ec;
                    //cst.mTypeInst              = new PTypeInst( gIJObject, 0, true );
                    //cst.mResolvedTypeInst      = new PTypeInst( gIJObject, 0, true );

                    //PExprTypecast vcst = new PExprTypecast;
                    //vcst.mTypeInst              = new PTypeInst( gBuildinTypePtr, 0, true );
                    //vcst.mResolvedTypeInst      = new PTypeInst( gBuildinTypePtr, 0, true );
                    //vcst.mExpr = cst;

                    //ecall.mArguments ~= vcst;
                    ecall.mArguments ~= ec;
                }
                else{
                    pd.mName = "lpObject";

                    PExprLiteral e = new PExprLiteral;
                    e.mType = LiteralType.LITERAL_this;
                    e.mText = "this";
                    //e.mResolvedTypeInst = new PTypeInst(gBuildinTypeVoid, 0, true);
                    e.mResolvedTypeInst = new PTypeInst(mCurrentTypeDef, 0, true);
                    ecall.mArguments ~= e;
                }


            }

            // prepend the parameter defs to the declaration
            PParameterDef[] params = m.mParams;
            foreach( inout PParameterDef pd; params ){
                PBuildinType bi = cast(PBuildinType) pd.mTypeInst.mTypeRef.mResolvedTypeDef;
                if( !( bi && pd.mTypeInst.mDimensions == 0 )){
                    pd.mTypeInst = new PTypeInst( gBuildinTypePtr, 0, true );
                }
            }
            m.mParams = prependParams ~ params;

            // append the addtional args to the call.
            foreach (PParameterDef pd; p.mParams) {
                PBuildinType bi = cast(PBuildinType) pd.mTypeInst.mTypeRef.mResolvedTypeDef;
                ecall.mArguments ~= new PExprVarRef(pd);
            }

            p.mStatList = new PStatList;
            if (p.mReturnType.mTypeRef.mResolvedTypeDef is gBuildinTypeVoid) {
                ecall.mAsStatement = true;
                p.mStatList.mStats ~= ecall;
            }
            else {
                PStatReturn sret = new PStatReturn;
                sret.mValue = ecall;
                p.mStatList.mStats ~= sret;
            }

        }
    }
}

class ModifierFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    override void visit(PInterfaceDef p){
        p.mModifiers.mVolatile = false;
        super.visit(p);
    }
    override void visit(PClassDef p){
        p.mModifiers.mVolatile = false;
        super.visit(p);
    }
    override void visit(PMethodDef p){
        p.mModifiers.mVolatile = false;
        switch (p.mModifiers.mProtection) {
        case Protection.PROTECTED:
        case Protection.NOTSET:
            p.mModifiers.mProtection = Protection.PUBLIC;

        default:
        }

        if (null !is cast(PInterfaceDef)mTypeDef) {
            p.mModifiers.mNative = false;
            p.mModifiers.mFinal  = false;
        }
        super.visit(p);
    }
    override void visit(PParameterDef p){
        p.mModifiers.mVolatile = false;
        p.mModifiers.mFinal    = false;
        super.visit(p);
    }
    override void visit(PVarDef p){
        p.mModifiers.mVolatile = false;
        p.mModifiers.mFinal    = false;
        super.visit(p);
    }
    override void visit(PFieldDef p){
        p.mModifiers.mVolatile = false;
        p.mModifiers.mFinal    = false;
        if (p.mModifiers.mProtection == Protection.NOTSET) {
            p.mModifiers.mProtection = Protection.PACKAGE;
        }
        super.visit(p);
    }
    override void visit(PLocalVarDef p){
        p.mModifiers.mVolatile = false;
        p.mModifiers.mFinal    = false;
        super.visit(p);
    }
}

class ToStringFixer : PartTraversVisitor {
    alias      PartTraversVisitor.visit visit;

    int getTraceLevel(){
        return(1);
    }
    PMethodDef mthToString;

    this(){
        foreach (PMethodDef m; gJObjectImpl.mMethods) {
            if (m.mName == "toString") {
                mthToString = m;
                break;
            }
        }
        assert(mthToString !is null);
    }
    PExprMethodCall getToString(PExpr e){
        PExprMethodCall ecall = new PExprMethodCall;

        ecall.mName             = "toString";
        ecall.mTrgExpr          = e;
        ecall.mResolvedCallable = mthToString;
        ecall.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
        return(ecall);
    }
    PExprNew getNewString(PExpr e){
        PExprNew enew = new PExprNew;

        enew.mTypeRef                  = new PTypeRef;
        enew.mTypeRef.mResolvedTypeDef = gTypeJavaLangString;
        enew.mArguments ~= e;
        enew.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
        enew.resolveCtor();
        return(enew);
    }

    override void visit(PExprBinary p){
        super.visit(p);
        if (p.mOp == "~") {
            assert(p.mLExpr !is null);
            assert(p.mLExpr.mResolvedTypeInst !is null, p.mLExpr.toUtf8);
            assert(p.mLExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(p.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);

            if (PBuildinType t = cast(PBuildinType)p.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef) {
                p.mLExpr = getNewString(p.mLExpr);
            }
            else if (p.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is gTypeJavaLangString) {
                p.mLExpr = getToString(p.mLExpr);
            }

            if (PBuildinType t = cast(PBuildinType)p.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef) {
                p.mRExpr = getNewString(p.mRExpr);
            }
            else if (p.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is gTypeJavaLangString) {
                p.mRExpr = getToString(p.mRExpr);
            }
        }
    }
    override void visit(PExprAssign p){
        super.visit(p);
        if (p.mOp == "~=") {
            p.mOp = "=";
            PExprBinary ebin = new PExprBinary;
            ebin.mOp               = "~";
            ebin.mLExpr            = p.mLExpr;
            ebin.mRExpr            = p.mRExpr;
            ebin.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
            p.mRExpr               = ebin;

            if (PBuildinType t = cast(PBuildinType)ebin.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef) {
                ebin.mRExpr = getNewString(ebin.mRExpr);
            }
            else if (ebin.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is gTypeJavaLangString) {
                ebin.mRExpr = getToString(ebin.mRExpr);
            }
        }
    }
}


class SwitchFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    int   methodIndex = 0;
    int getTraceLevel(){
        return(1);
    }

    override void visit(PModule p){
        methodIndex = 0; // reset for every module, so there are no differences in the code if the count of modules changes
        super.visit(p);
    }

    override void visit(PStatSwitch p){
        super.visit(p);

        methodIndex++;
        char[]     swMethName  = Layouter("calc_switch_value_GENERATED_{0}", methodIndex);
        char[]     swParamName = "aValue";

        PStatList  slist = new PStatList;

        PMethodDef swMeth = new PMethodDef;
        swMeth.mIsNestedFunc = true;
        swMeth.mModifiers             = new PModifiers;
        swMeth.mModifiers.mProtection = Protection.NOTHING;
        swMeth.mName                  = swMethName;
        swMeth.mReturnType            = new PTypeInst(gBuildinTypeInt, 0, true);
        swMeth.mStatList              = new PStatList;

        PParameterDef swParam = new PParameterDef(mModule);
        swParam.mModifiers = new PModifiers;
        swParam.mName      = swParamName;
        swParam.mTypeInst  = p.mSwitch.mResolvedTypeInst;
        swMeth.mParams ~= swParam;

        PStatReturn makeReturn(int aValue){
            PStatReturn  sret   = new PStatReturn;
            PExprLiteral retVal = new PExprLiteral;

            sret.mValue              = retVal;
            retVal.mType             = LiteralType.NUM_INT;
            retVal.mText             = Layouter("{0}", aValue);
            retVal.mResolvedTypeInst = new PTypeInst(gBuildinTypeInt, 0, true);
            return(sret);
        }

        //PExpr[]   mCases;
        int defVal = p.mCaseGroups.length;
        foreach (int i, PCaseGroup cg; p.mCaseGroups) {
            foreach (PExpr ecase; cg.mCases) {
                PStatIf     sif = new PStatIf;
                PExprBinary eq  = new PExprBinary;
                eq.mOp = "==";

                PExprVarRef eval = new PExprVarRef;
                eval.mParameterDef     = swParam;
                eval.mResolvedTypeInst = p.mSwitch.mResolvedTypeInst;
                eq.mLExpr              = eval;

                eq.mRExpr = ecase;

                sif.mCond  = eq;
                sif.mTCase = makeReturn(i);
                swMeth.mStatList.mStats ~= sif;
            }
            if (cg.mIsDefault) {
                defVal = i;
            }
        }
        swMeth.mStatList.mStats ~= makeReturn(defVal);

        slist.mStats ~= swMeth;

        PStatSwitch     ssw   = new PStatSwitch;
        PExprMethodCall ecall = new PExprMethodCall;
        ecall.mName    = swMethName;
        ecall.mTrgExpr = null;
        ecall.mArguments ~= p.mSwitch;
        ecall.mResolvedCallable = swMeth;
        ssw.mSwitch             = ecall;

        // move local var defs from top scope level out, because in D
        // each case make a new scope
        foreach (int i, PCaseGroup cg; p.mCaseGroups) {
            PStatList todo = cg.mTodo;
            if( todo is null ){
                continue;
            }
            PStatement[] nstats;
            foreach( PStatement stat; todo.mStats ){
                if( PLocalVarDef vdef = cast(PLocalVarDef)stat ){
                    if( vdef.mInitializer !is null ){
                        PVarInitExpr ie = cast(PVarInitExpr)vdef.mInitializer;
                        assert( ie !is null );
                        PExprAssign eass = new PExprAssign();
                        PExprVarRef vref = new PExprVarRef();
                        vref.mParameterDef     = vdef;
                        vref.mResolvedTypeInst = vdef.mTypeInst.clone();
                        //vref.mExprReference    = cur;

                        eass.mLExpr = vref;
                        eass.mOp = "=";
                        eass.mRExpr = ie.mExpr;
                        eass.mAsStatement = true;
                        eass.mResolvedTypeInst = vdef.mTypeInst.clone();
                        nstats ~= eass;
                    }
                    vdef.mInitializer = null;
                    slist.mStats ~= stat;
                }
                else{
                    nstats ~= stat;
                }
            }
            todo.mStats = nstats;
        }

        slist.mStats ~= ssw;

        foreach (int i, PCaseGroup cg; p.mCaseGroups) {
            PCaseGroup   newCaseGroup = new PCaseGroup;
            PExprLiteral eCaseNum     = new PExprLiteral;
            eCaseNum.mType             = LiteralType.NUM_INT;
            eCaseNum.mText             = Layouter("{0}", i);
            eCaseNum.mResolvedTypeInst = new PTypeInst(gBuildinTypeInt, 0, true);
            newCaseGroup.mCases ~= eCaseNum;
            newCaseGroup.mTodo = cg.mTodo;
            ssw.mCaseGroups ~= newCaseGroup;
        }
        if( defVal == p.mCaseGroups.length ){
            // there was no default. In java this is no problem,
            // in D a runtime error will be generated.
            // So add a default, that makes nothing
            PCaseGroup   newCaseGroup = new PCaseGroup;
            PExprLiteral eCaseNum     = new PExprLiteral;
            eCaseNum.mType             = LiteralType.NUM_INT;
            eCaseNum.mText             = Layouter("{0}", defVal);
            eCaseNum.mResolvedTypeInst = new PTypeInst(gBuildinTypeInt, 0, true);
            newCaseGroup.mCases ~= eCaseNum;
            ssw.mCaseGroups ~= newCaseGroup;
        }

        p.mPartParent.exchangeStat(p, slist);
    }
}


class InitFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    int getTraceLevel(){
        return(1);
    }

    override void visit(PClassDef p){
        refactorStatic(p);
        refactorInstance(p);
        super.visit(p);
    }

    PStatement makeVarInit(PFieldDef fd){
        PStatList   slist = new PStatList;
        PExprAssign eass  = new PExprAssign;

        eass.mOp = "=";
        PExprVarRef ident = new PExprVarRef;
        ident.mParameterDef     = fd;
        ident.mResolvedTypeInst = fd.mTypeInst;
        eass.mLExpr             = ident;
        eass.mRExpr             = fd.mInitializer;
        eass.mResolvedTypeInst  = fd.mTypeInst;
        eass.mAsStatement       = true;
        slist.mStats ~= eass;

        fd.mInitializer      = null;
        fd.mModifiers.mFinal = false;
        return(slist);
    }

    bool isComplex(PVarInitializer p){
        auto finder = new ComplexFinder;

        p.accept(finder);
        return(finder.isComplex);
    }

    class ComplexFinder : PartTraversVisitor {
        alias PartTraversVisitor.visit visit;
        bool  isComplex = false;
        override void visit(PExprNew p){
            isComplex = true;
        }
        override void visit(PExprNewArray p){
            isComplex = true;
        }
        override void visit(PExprNewAnon p){
            isComplex = true;
        }
        override void visit(PExprMethodCall p){
            isComplex = true;
        }
        override void visit(PExprVarRef p){
            isComplex = true;
        }
        override void visit(PExprFncRef p){
            isComplex = true;
        }
        override void visit(PVarInitArray p){
            isComplex = true;
        }
    }

    void refactorInstance(PClassDef p){
        PStatement[] stats;
        int          checkFields = 0;
        int          checkCtors  = 0;
        foreach (PPart part; p.mOriginalDeclOrder) {
            if (PFieldDef fd = cast(PFieldDef)part) {
                if (!fd.mModifiers.isStatic) {
                    if (fd.mInitializer !is null && isComplex(fd.mInitializer)) {
                        stats ~= makeVarInit(fd);
                    }
                    checkFields++;
                }
            }
            if (PInstanceInit ctor = cast(PInstanceInit)part) {
                stats ~= ctor.mStatList;
                checkCtors++;
            }
        }

        int          checkFieldsVerify = 0;
        foreach (PFieldDef fd; p.mFields) {
            if (!fd.mModifiers.isStatic) {
                checkFieldsVerify++;
            }
        }

        assert(checkFields == checkFieldsVerify, "orig consistence?");
        assert(checkCtors == p.mInstanceInits.length, "orig consistence?");

        p.mInstanceInits = null;

        if (stats.length > 0) {
            char[]     initName = "GENERATED_INSTANCE_INIT";
            PMethodDef initMeth = new PMethodDef;
            initMeth.mModifiers             = new PModifiers;
            initMeth.mModifiers.mProtection = Protection.PRIVATE;
            initMeth.mName                  = initName;
            initMeth.mReturnType            = new PTypeInst(gBuildinTypeVoid, 0, true);
            initMeth.mStatList              = new PStatList;
            initMeth.mStatList.mStats       = stats;
            p.mMethods ~= initMeth;

            PExprMethodCall makeInitCall(){
                PExprMethodCall ecall = new PExprMethodCall;

                ecall.mResolvedCallable = initMeth;
                ecall.mAsStatement      = true;
                return(ecall);
            }

            if (p.mCtors.length > 0) {
                foreach (PCtor ctor; p.mCtors) {
                    bool foundThisCall = false;
                    foreach (PStatement stat; ctor.mStatList.mStats) {
                        if (PExprMethodCall c = cast(PExprMethodCall)stat) {
                            if (c.mName == "this") {
                                //bool found = false;
                                //foreach (PCtor searchCtor; p.mCtors) {
                                //    if (c.mResolvedCallable is searchCtor) {
                                //        found = true;
                                //    }
                                //}
                                //if (!found) {
                                    foundThisCall = true;
                                //    break;
                                //}
                            }
                        }
                    }
                    if (!foundThisCall) {
                        ctor.mStatList.mStats = cast(PStatement)makeInitCall() ~ctor.mStatList.mStats;
                    }
                }
            }
            else {
                PCtor defCtor = new PCtor;
                defCtor.mModifiers             = new PModifiers;
                defCtor.mModifiers.mProtection = Protection.PUBLIC;
                defCtor.mStatList              = new PStatList;
                defCtor.mStatList.mStats ~= makeInitCall();
                p.mCtors ~= defCtor;
            }
        }
    }
    void refactorStatic(PClassDef p){
        PStatement[] stats;
        int          checkFields = 0;
        int          checkCtors  = 0;
        foreach (PPart part; p.mOriginalDeclOrder) {
            if (PFieldDef fd = cast(PFieldDef)part) {
                if (fd.mModifiers.isStatic) {
                    if (fd.mInitializer !is null && isComplex(fd.mInitializer)) {
                        stats ~= makeVarInit(fd);
                    }
                    checkFields++;
                }
            }
            if (PStaticCtor ctor = cast(PStaticCtor)part) {
                stats ~= ctor.mStatList;
                checkCtors++;
            }
        }

        int          checkFieldsVerify = 0;
        foreach (PFieldDef fd; p.mFields) {
            if (fd.mModifiers.isStatic) {
                checkFieldsVerify++;
            }
        }

        assert(checkFields == checkFieldsVerify, "orig consistence?");
        assert(checkCtors == p.mStaticCtors.length, "orig consistence?");

        p.mStaticCtors = null;
        if (stats.length > 0) {
            PStaticCtor ctor = new PStaticCtor;
            ctor.mModifiers         = new PModifiers;
            ctor.mModifiers.mStatic = true;
            ctor.mStatList          = new PStatList;
            ctor.mStatList.mStats   = stats;
            p.mStaticCtors ~= ctor;
        }
    }

    private int getArrayDimFromArrayTypeInst( PTypeInst aTi ){
        int dim = 1;
        PTypeInst cur = aTi;
        while( cur.mTypeRef.mGenericArgs.length == 1 && isArrayType( cur.mTypeRef.mGenericArgs[0].mTypeRef.mResolvedTypeDef ) ){
            cur = cur.mTypeRef.mGenericArgs[0];
            dim++;
        }
        return dim;
    }
    private PTypeInst getElementTypeInstFromArrayTypeInst( PTypeInst aTi ){
        PTypeInst cur = aTi;
        while( true ){
            assert( cur.mTypeRef.mGenericArgs.length == 1 );
            if( !isArrayType( cur.mTypeRef.mGenericArgs[0].mTypeRef.mResolvedTypeDef )){
                return cur.mTypeRef.mGenericArgs[0];
            }
            cur = cur.mTypeRef.mGenericArgs[0];
        }
        assert( false );
    }
    private PTypeInst getTopArrayTypeInstFromArrayTypeInst( PTypeInst aTi ){
        PTypeInst cur = aTi;
        while( true ){
            assert( cur.mTypeRef.mGenericArgs.length == 1 );
            if( !isArrayType( cur.mTypeRef.mGenericArgs[0].mTypeRef.mResolvedTypeDef )){
                return cur;
            }
            cur = cur.mTypeRef.mGenericArgs[0];
        }
        assert( false );
    }
    private PExprMethodCall varInitArray2PExprNew(PVarInitArray e, PTypeInst aTi ){
        PExprMethodCall ecall = new PExprMethodCall();
        if( aTi.mTypeRef.mResolvedTypeDef is gJArrayJObject ){
            // classinfo
            PTypeInst ti = getTopArrayTypeInstFromArrayTypeInst( aTi );
            if( ti.mTypeRef.mResolvedTypeDef is gJArrayJObject ){
                ti = ti.mTypeRef.mGenericArgs[0];
            }
            ecall.mArguments ~= makeClassInfo( ti.mTypeRef.mResolvedTypeDef );

            // dim
            ecall.mArguments ~= makeLiteralIntegerHex( getArrayDimFromArrayTypeInst( aTi ) );
        }
        PClassDef cd = cast(PClassDef)aTi.mTypeRef.mResolvedTypeDef;
        ecall.mResolvedTypeInst = aTi.clone();
        ecall.mResolvedCallable = cd.findMethod( "createSimpleFromLiteral" );
        ecall.mName = ecall.mResolvedCallable.mName.dup;
        {
            PExprTypeInst eti = new PExprTypeInst;
            eti.mResolvedTypeInst = aTi;
            ecall.mTrgExpr = eti;
        }
        foreach (inout PVarInitializer i; e.mInitializers) {
            if (PVarInitArray inita = cast(PVarInitArray)i) {
                // initializers
                ecall.mArguments ~= varInitArray2PExprNew( inita, aTi.mTypeRef.mGenericArgs[0] );
            }
            else if (PVarInitExpr inite = cast(PVarInitExpr)i) {
                // initializers
                ecall.mArguments ~= inite;
            }
        }
        return ecall;
    }
    private PTypeInst[] getArrayTypes( PTypeInst aTi ){
        PTypeInst[] tis;
        PTypeInst cur = aTi;
        while( cur !is null ){
            tis ~= cur;
            cur = cur.mTypeRef.mGenericArgs !is null ? cur.mTypeRef.mGenericArgs[0] : null;
        }
        return tis;
    }
    private void fixInitializer( inout PVarInitializer e, PTypeInst aTypeInst){
        if (PVarInitArray inita = cast(PVarInitArray)e) {
            PExprMethodCall enew = varInitArray2PExprNew(inita, buildArrayTypeInst( aTypeInst ) );
            e = new PVarInitExpr( enew );
        }
    }
    private void fixExpr( inout PExpr e, PTypeInst aTypeInst){
        if (PVarInitArray inita = cast(PVarInitArray)e) {
            e = varInitArray2PExprNew(inita, buildArrayTypeInst( aTypeInst ) );
        }
    }
    override void visit(PVarDef p){
        super.visit(p);
        if (p.mInitializer !is null) {
            fixInitializer(p.mInitializer, p.mTypeInst);
        }
        checkDoubleFloatWcharTypesInit( p );
    }

    override void visit(PLocalVarDef p){
        super.visit(p);
        if (p.mInitializer !is null) {
            fixInitializer(p.mInitializer, p.mTypeInst);
        }
        checkDoubleFloatWcharTypesInit( p );
    }

    override void visit(PExprNewArray p){
        super.visit(p);
        PTypeDef td = p.mResolvedTypeInst.mTypeRef.mResolvedTypeDef;
        PClassDef acd = gJArrayJObject;
        if( td is gBuildinTypeBoolean ) acd = gJArrayBoolean;
        if( td is gBuildinTypeByte    ) acd = gJArrayByte   ;
        if( td is gBuildinTypeShort   ) acd = gJArrayShort  ;
        if( td is gBuildinTypeInt     ) acd = gJArrayInt    ;
        if( td is gBuildinTypeLong    ) acd = gJArrayLong   ;
        if( td is gBuildinTypeFloat   ) acd = gJArrayFloat  ;
        if( td is gBuildinTypeDouble  ) acd = gJArrayDouble ;
        if( td is gBuildinTypeChar    ) acd = gJArrayChar   ;

        int dim = p.mArrayDecls.length;

        if (p.mInitializer !is null) {
            // if initializier is given, the dimension expresions must not exist.
            PTypeInst el = p.mResolvedTypeInst.clone;
            assert( el.mDimensions > 0 );
            PTypeInst ti = buildArrayTypeInst( el );

            /*
            while( dim > 1 ){
                PTypeInst ti = new PTypeInst( gJArrayJObject, 0, true );
                ti.mJArrayDimensions = dim;
                ti.mJArrayElementType = p.mResolvedTypeInst.clone();
                ti.mJArrayElementType.mDimensions = 0;
                tis ~= ti;
                dim--;
            }
            {
                PTypeInst ti = new PTypeInst( acd, 0, true );
                ti.mJArrayDimensions = dim;
                ti.mJArrayElementType = p.mResolvedTypeInst.clone();
                ti.mJArrayElementType.mDimensions = 0;
                tis ~= ti;
            }
            */
            PExprMethodCall ecall = varInitArray2PExprNew( p.mInitializer, ti );
            p.mPartParent.exchangeExpr( p, ecall );
        }
        else{
           PExprMethodCall ecall = new PExprMethodCall();
           ecall.mName = ( dim == 1 ) ? "createSimple" : "createRectangular";
           ecall.mResolvedCallable = acd.findMethod( ecall.mName );
           ecall.mResolvedTypeInst = new PTypeInst( acd, 0, true );
           {
               PExprTypeInst eti = new PExprTypeInst;
               eti.mResolvedTypeInst = new PTypeInst(acd, 0, false);
               ecall.mTrgExpr = eti;
           }
           if( acd !is gJArrayJObject ){
               // public static JArrayT!(T) createSimple( int aSize ){
               // public static JArrayJObject createRectangular( int aDims, int[] aSizes... ){
               if( dim > 1 ){
                   ecall.mArguments ~= makeLiteralIntegerHex( 1 );
               }
           }
           else{
               // public static JArrayJObject createSimple( object.ClassInfo aCi, int aDims, int aSize ){
               // public static JArrayJObject createRectangular( object.ClassInfo aCi, int aDims, int[] aSizes... ){

               if( acd is gJArrayJObject ){
                   ecall.mArguments ~= makeClassInfo( td );
               }
               else{
                   ecall.mArguments ~= makeClassInfo( acd );
               }

               ecall.mArguments ~= makeLiteralIntegerHex( dim );
           }
           for( int i = 0; i < p.mArrayDecls.length; i++ ){
               int idx = p.mArrayDecls.length - i -1;
               if( p.mArrayDecls[idx].mCount !is null ){
                   ecall.mArguments ~= p.mArrayDecls[idx].mCount;
               }
           }
           p.mPartParent.exchangeExpr( p, ecall );
        }
    }

    override void visit(PFieldDef p){
        super.visit(p);
        if (p.mInitializer !is null) {
            fixInitializer(p.mInitializer, p.mTypeInst);
        }
        checkDoubleFloatWcharTypesInit( p );
    }

    override void visit(PExprAssign p){
        super.visit(p);
        fixExpr(p.mRExpr, p.mResolvedTypeInst);
    }

    override void visit(PStatReturn p){
        super.visit(p);
        if (PMethodDef c = cast(PMethodDef)mCallable) {
            if (p.mValue !is null) {
                fixExpr(p.mValue, c.mReturnType);
            }
        }
    }

    private void checkDoubleFloatWcharTypesInit( PVarDef vd ){
        if( vd.mInitializer !is null ){
            return;
        }
        PTypeDef td = vd.mTypeInst.mTypeRef.mResolvedTypeDef;
        if( td !is gBuildinTypeChar && td !is gBuildinTypeFloat && td !is gBuildinTypeDouble ){
            return;
        }
        PExprLiteral e = new PExprLiteral();
        if( td is gBuildinTypeDouble ){
            e.mType = LiteralType.NUM_DOUBLE;
            e.mText = "0.0";
        }
        if( td is gBuildinTypeFloat ){
            e.mType = LiteralType.NUM_FLOAT;
            e.mText = "0.0f";
        }
        if( td is gBuildinTypeChar ){
            e.mType = LiteralType.NUM_INT;
            e.mText = "0";
        }
        e.mResolvedTypeInst = new PTypeInst( td, 0, true );
        PVarInitExpr ie = new PVarInitExpr;
        ie.mExpr = e;
        ie.mResolvedTypeInst = e.mResolvedTypeInst.clone;
        vd.mInitializer = ie;
    }
}



PClassDef getArrayClassDef( PTypeDef td ){
    if( td is gBuildinTypeBoolean ){ return gJArrayBoolean; }
    if( td is gBuildinTypeByte    ){ return gJArrayByte   ; }
    if( td is gBuildinTypeShort   ){ return gJArrayShort  ; }
    if( td is gBuildinTypeInt     ){ return gJArrayInt    ; }
    if( td is gBuildinTypeLong    ){ return gJArrayLong   ; }
    if( td is gBuildinTypeFloat   ){ return gJArrayFloat  ; }
    if( td is gBuildinTypeDouble  ){ return gJArrayDouble ; }
    if( td is gBuildinTypeChar    ){ return gJArrayChar   ; }
    return gJArrayJObject;
}

class StubMissingReturnFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    int getTraceLevel(){
        return(1);
    }
    override void visit(PMethodDef p){
        super.visit(p);

        if ((cast(PClassDef)mTypeDef) is null) {
            return;
        }

        if (mModule.mIsStub && !p.mModifiers.mAbstract) {
            //Stdout.formatln( "---------" );
            // erase and make new
            p.mStatList = new PStatList;

            PExprLiteral slit   = null;
            bool         doNull = false;
            if (PBuildinType t = cast(PBuildinType)p.mReturnType.mTypeRef.mResolvedTypeDef) {
                if (p.mReturnType.mDimensions > 0) {
                    goto LdoNull;
                }
                if (t !is gBuildinTypeVoid) {
                    slit                   = new PExprLiteral;
                    slit.mType             = t.mLiteralType;
                    slit.mText             = t.mDefaultValue;
                    slit.mResolvedTypeInst = p.mReturnType;
                }
            }
            else {
LdoNull:
                slit                   = new PExprLiteral;
                slit.mType             = LiteralType.LITERAL_null;
                slit.mText             = "null";
                slit.mResolvedTypeInst = p.mReturnType;
            }

            PStatAssert  sass   = new PStatAssert;
            PExprLiteral efalse = new PExprLiteral;
            efalse.mType             = LiteralType.LITERAL_false;
            efalse.mText             = "false";
            efalse.mResolvedTypeInst = new PTypeInst(gBuildinTypeBoolean, 0, true);
            sass.mCond               = efalse;
            PExprLiteral emsg = new PExprLiteral;
            emsg.mType             = LiteralType.STRING_LITERAL;
            emsg.mText             = "\"implementation missing\"";
            emsg.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
            sass.mMsg              = emsg;
            p.mStatList.mStats ~= sass;

            if (slit !is null) {
                PStatReturn sret = new PStatReturn;
                sret.mValue = slit;
                p.mStatList.mStats ~= sret;
            }
        }
    }
}

class InnerClassThisCastFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;
    int getTraceLevel(){
        return(1);
    }
    PClassDef classDef;
    override void visit(PClassDef p){
        PClassDef bak = classDef;
        classDef = p;
        super.visit(p);
        classDef = bak;
    }
    override void visit(PExprVarRef p){
        super.visit(p);
        if( p.mParameterDef.mName != "this" ){
            return;
        }
        //if( p.mFromTypeDef is null && p.mExprReference is null ){
        if( p.mFromTypeDef is null ){
            return;
        }
        // Java: MyClass.this
        // D   : this.outer
        PClassDef cd = classDef;
        PExprVarRef cur = p;
        while( true ){
            if( cd is (cast(PClassDef) p.mFromTypeDef) ){
                break;
            }

            PClassDef outerClass = null;
            if( cd.mOuter !is null ){
                outerClass = cast(PClassDef) cd.mOuter.mTypeInst.mTypeRef.mResolvedTypeDef;
            }
            assert( outerClass !is null );

            PExprVarRef vref = new PExprVarRef;
            vref.mParameterDef     = cd.mOuter;
            vref.mResolvedTypeInst = new PTypeInst( outerClass, 0, true );
            vref.mExprReference    = cur;

            cd = outerClass;
            cur = vref;
        }
        p.mPartParent.exchangeExpr(p, cur);
    }
}

class ClassObjectPropertyFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    override void visit(PExprVarRef p){
        super.visit(p);

        if (p.mParameterDef.mName != "class") {
            return;
        }

        PExprMethodCall etypeid = new PExprMethodCall;
        etypeid.mResolvedCallable = gFncClassInfo;
        if( p.mFromTypeDef !is null ){
            PExprTypeInst eti = new PExprTypeInst;
            eti.mResolvedTypeInst = new PTypeInst(p.mFromTypeDef, 0, false);
            etypeid.mTrgExpr = eti;
        }
        else if( p.mExprReference !is null ){
            etypeid.mTrgExpr = p.mExprReference;
        }
        etypeid.mResolvedTypeInst = new PTypeInst(gClsTypeInfo, 0, false);

        PExprMethodCall ecall    = new PExprMethodCall;
        PExprTypeInst   ecallTrg = new PExprTypeInst;
        ecallTrg.mResolvedTypeInst = new PTypeInst(gClsJavaLangClass, 0, false);
        ecall.mTrgExpr             = ecallTrg;
        ecall.mResolvedCallable    = gFncJavaLangClassGetClassObject;
        ecall.mArguments ~= etypeid;
        ecall.mResolvedTypeInst = gFncJavaLangClassGetClassObject.mReturnType;

        p.mPartParent.exchangeExpr(p, ecall);
    }
}

class AnonymousClassFixer : PartTraversVisitor {
    alias     PartTraversVisitor.visit visit;
    int getTraceLevel(){
        return(1);
    }
    PClassDef mClassDef;

    PClassDef[][PClassDef] mNewClassDefs;

    override void visit(PClassDef p){
        PClassDef bak = mClassDef;

        mClassDef = p;
        super.visit(p);
        mClassDef = bak;

        if (p in mNewClassDefs) {
            PClassDef[] newInnerClasses = mNewClassDefs[p];
            if (newInnerClasses !is null) {
                p.mTypeDefs ~= newInnerClasses;
            }
        }
    }
    override void visit(PExprNewAnon p){
        PClassDef bak = mClassDef;

        //PFieldDef outerField = new PFieldDef( mModule );
        //outerField.mModifiers = new PModifiers;
        //outerField.mTypeInst  = new PTypeInst( mClassDef, 0, true );
        //outerField.mName      = "outer";
        //p.mClassDef.mOuter = outerField;
        assert( p.mClassDef.mOuter !is null );

        mClassDef = p.mClassDef;

        super.visit(p);

        PTypeInst[] ctorArgTypes;
        foreach( PExpr exp; p.mArguments ){
            //Stdout.formatln( " arg {0}", exp.mResolvedTypeInst.toUtf8 );
            ctorArgTypes ~= exp.mResolvedTypeInst;
        }

        PCtor calledCtor;

        if (p.mClassDef.mSuperClass !is null) {
            PCtor     ctor;
            PCtor     superctor;
            bool log = false;
            //FIXME if the new expr does have args, then the appropriate ctor must be search. Actually only a std ctor is searched.
            PClassDef sc = cast(PClassDef)p.mClassDef.mSuperClass.mResolvedTypeDef;
            assert( sc !is null );
            //Stdout.formatln( " super class {0} ", sc.mName );
            foreach( PCtor c; sc.mCtors ){
                //Stdout.formatln( " super class ctor: {0} ", c.toUtf8 );
            }

            // every class has at minimum one ctor, the one generated in BaseFixer
            assert (sc.mCtors.length > 0);

            PCtor foundCtor = cast(PCtor) sc.findCallable( "this", ctorArgTypes , true );
            assert(foundCtor !is null);

            if( foundCtor.mParams.length == 0 ){
                ctor = cast(PCtor) p.mClassDef.findCallable( "this", ctorArgTypes , true );
            }
            else{
                ctor                        = p.mClassDef.mCtors[0]; // BaseFixer already added a std ctor, use and extend it.
                ctor.mModifiers             = new PModifiers;
                ctor.mModifiers.mProtection = Protection.PUBLIC;
                ctor.mStatList              = new PStatList;
                foreach( PParameterDef pd; foundCtor.mParams ){
                    ctor.mParams ~= pd.clone();
                    //Stdout.formatln( " Param {0}", pd.mTypeInst.toUtf8 );
                }
                // do not readd, using the existing std ctor, see above.
                // p.mClassDef.mCtors ~= ctor;
            }
            calledCtor = ctor;

            // due to a compiler bug, add a std ctor here
            PExprMethodCall supercall = new PExprMethodCall;
            supercall.mName             = "super";
            supercall.mResolvedCallable = foundCtor;
            supercall.mAsStatement      = true;
            foreach( PParameterDef pd; ctor.mParams ){
                supercall.mArguments ~= new PExprVarRef( pd );
            }
            ctor.mStatList.mStats ~= supercall;
        }

        mClassDef = bak;

        // transfor the anonymous class into a normal inner class.
        PClassDef anonClass = p.mClassDef;

        // add the class to the outers child typedefs
        assert(mClassDef !is null);
        if (mClassDef in mNewClassDefs) {
            PClassDef[] defs;
            defs = mNewClassDefs[mClassDef];
            defs ~= anonClass;
            mNewClassDefs[mClassDef] = defs;
        }
        else {
            PClassDef[] defs;
            defs ~= anonClass;
            mNewClassDefs[mClassDef] = defs;
        }

        // the instantiating method is static, the class itself is also static. The method has no this, so it cannot instanciate a non-static inner class.
        anonClass.mModifiers.mStatic = mCallable.mModifiers.mStatic;

        ////mClassDef.mTypeDefs ~= p.mClassDef;
        //// replace the pexprnewanon with a pexprnew
        PExprNew enew = new PExprNew;
        enew.mTypeRef                  = new PTypeRef;
        enew.mTypeRef.mResolvedTypeDef = anonClass;
        enew.mArguments                = p.mArguments;
        enew.mResolvedTypeInst         = p.mResolvedTypeInst;
        enew.resolveCtor();
        p.mPartParent.exchangeExpr(p, enew);

        //// make a list of all internal PExprVarRef, pointing to a 'final' PParameterDef or PLocalVarDef.
        // search all 'final' PParameterDefs references from inside the class
        alias                            HashSet!(PParameterDef) TParameterDefs;
        AnonymousClassVarRefFinder       finder = new AnonymousClassVarRefFinder;
        anonClass.accept(finder);
        PExprVarRef[]                    internalFinalVars = finder.mVarRefs;

        AnonymousClassParameterDefFinder pdfinder = new AnonymousClassParameterDefFinder(finder.mParameterDefs);
        mCallable.accept(pdfinder);

        assert ( calledCtor !is null ) ;
        PCtor ctor = calledCtor;

        PParameterDef[PParameterDef] definitionMap;
        // Sort the params before adding it, this prevents the generated code from being different every time.
        TreeMap!( char[], PParameterDef ) sortedKeys = new TreeMap!(char[], PParameterDef );
        foreach( PParameterDef pd; pdfinder.mSearchedParameterDefs ){
            sortedKeys.add( pd.mName, pd );
        }
        auto it = sortedKeys.elements;
        while (it.more()) {
            // add all found ParameterDefs to the arguement list of the ctor.
            PParameterDef def    = it.get();
            PParameterDef newDef = new PParameterDef(mModule);
            newDef.mModifiers = def.mModifiers.clone();
            newDef.mTypeInst  = def.mTypeInst.clone();
            newDef.mName      = "par_" ~ def.mName; // umbennenen spart später das "this." bei feldzuweisung
            ctor.mParams ~= newDef;
            // add all found ParameterDefs to the field list of the class
            PFieldDef newFld = new PFieldDef(mModule);
            newFld.mModifiers = def.mModifiers.clone();
            newFld.mTypeInst  = def.mTypeInst.clone();
            newFld.mName      = def.mName.dup;
            anonClass.mFields ~= newFld;

            definitionMap[def] = newFld;

            // let the ctor copy the argument values to the fields
            PExprAssign eass = new PExprAssign;
            eass.mAsStatement      = true;
            eass.mLExpr            = new PExprVarRef(newFld);
            eass.mRExpr            = new PExprVarRef(newDef);
            eass.mResolvedTypeInst = newFld.mTypeInst;
            eass.mOp               = "=";
            ctor.mStatList.mStats ~= eass;

            // let the new expression pass the arguments to the ctor
            enew.mArguments ~= new PExprVarRef(def);
        }
        // change all references to the internal fields.
        VarRefRemapper remapper = new VarRefRemapper(definitionMap);
        anonClass.accept(remapper);
    }

    class VarRefRemapper : PartTraversVisitor {
        alias PartTraversVisitor.visit visit;
        PParameterDef[PParameterDef] mDefMap;
        this(PParameterDef[PParameterDef] aDefMap){
            mDefMap = aDefMap;
        }
        override void visit(PExprVarRef p){
            super.visit(p);
            if (p.mParameterDef in mDefMap) {
                p.mParameterDef = mDefMap[p.mParameterDef];
            }
        }
    }

    class AnonymousClassParameterDefFinder : PartTraversVisitor {
        alias          PartTraversVisitor.visit visit;
        alias          HashSet!(PParameterDef) TParameterDefs;
        TParameterDefs mReferencedParameterDefs;
        TParameterDefs mSearchedParameterDefs;
        this(TParameterDefs aReferencesParameterDefs){
            mReferencedParameterDefs = aReferencesParameterDefs;
            mSearchedParameterDefs   = new TParameterDefs;
        }
        override void visit(PParameterDef p){
            super.visit(p);
            if (mReferencedParameterDefs.contains(p)) {
                mSearchedParameterDefs.add(p);
            }
        }
        override void visit(PLocalVarDef p){
            super.visit(p);
            if (mReferencedParameterDefs.contains(p)) {
                mSearchedParameterDefs.add(p);
            }
        }
    }

    class AnonymousClassVarRefFinder : PartTraversVisitor {
        alias          PartTraversVisitor.visit visit;
        PExprVarRef[]  mVarRefs;
        alias          HashSet!(PParameterDef) TParameterDefs;
        TParameterDefs mParameterDefs;

        this(){
            mParameterDefs = new TParameterDefs;
        }

        override void visit(PExprVarRef p){
            super.visit(p);
            if (PFieldDef fd = cast(PFieldDef)p.mParameterDef) {
            }
            else if (PLocalVarDef fd = cast(PLocalVarDef)p.mParameterDef) {
                if (fd.mModifiers.mFinal) {
                    mVarRefs ~= p;
                    mParameterDefs.add(fd);
                }
            }
            else if (PVarDef fd = cast(PVarDef)p.mParameterDef) {
            }
            else if (PParameterDef fd = cast(PParameterDef)p.mParameterDef) {
                if (fd.mModifiers.mFinal) {
                    mVarRefs ~= p;
                    mParameterDefs.add(fd);
                }
            }
        }
    }
}

/**
 * collect all Method names and test if a field is called like an existing method.
 * If there is a conflict, rename the field to "fld_<oldname>".
 *
 * if
 */
class UniqueFieldAndMethodsFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;
    int getTraceLevel(){
        return(1);
    }

    alias HashSet!(char[]) TSet;

    PFieldDef[] fieldNames;
    TSet       methNames;

    public this(){
    }

    override void visit(PClassDef p){
        fieldNames = null;
        methNames = new TSet();
        PClassDef cls = p;
        while (cls !is null) {
            foreach (PMethodDef m; cls.mMethods) {
                methNames.add(m.mName);
            }
            foreach (PFieldDef m; cls.mFields) {
                if(( !m.mModifiers.mProtection != Protection.PRIVATE || cls is p ) && ( m.mTypeInst.mDimensions == 0 ) ){
                    fieldNames ~= m;
                }
            }
            if (cls.mSuperClass is null) {
                break;
            }
            cls = cast(PClassDef)cls.mSuperClass.mResolvedTypeDef;
        }

        foreach (PFieldDef f; fieldNames) {
            if (methNames.contains(f.mName)) {
                f.mName = "fld_" ~ f.mName;
            }
        }

        super.visit(p);
    }

    override void visit(PParameterDef p){
        super.visit(p);
        if (methNames.contains(p.mName)) {
            p.mName = "par_" ~ p.mName;
        }
    }
    override void visit(PLocalVarDef p){
        super.visit(p);
        if (methNames.contains(p.mName)) {
            p.mName = "var_" ~ p.mName;
        }
    }
}
class RenameShadowingVarsFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;
    bool[ char[] ] vars;
    int shadowIdx = 0;

    private void reset(){
        vars = null;
        shadowIdx = 0;
    }
    override void visit(PCtor p){
        reset();
        super.visit(p);
    }

    override void visit(PMethodDef p){
        reset();
        super.visit(p);
    }

    override void visit(PStaticCtor p){
        reset();
        super.visit(p);
    }

    private void check(PParameterDef p){
        if(( p.mName in vars ) !is null ){
            char[] name = Layouter( "{}_shadow{}", p.mName, shadowIdx );
            p.mName = name;
        }
        vars[ p.mName ] = true;
    }
    override void visit(PParameterDef p){
        check( p );
        super.visit(p);
    }
    override void visit(PVarDef p){
        check( p );
        super.visit(p);
    }
    override void visit(PLocalVarDef p){
        check( p );
        super.visit(p);
    }
    override void visit(PStatFor p){
        char[][] oldvars = vars.keys.dup;
        super.visit(p);
        vars = null;
        foreach( char[] v; oldvars ){
            vars[ v ] = true;
        }
    }
    override void visit(PStatCatch p){
        char[][] oldvars = vars.keys.dup;
        super.visit(p);
        vars = null;
        foreach( char[] v; oldvars ){
            vars[ v ] = true;
        }
    }
    override void visit(PStatList p){
        char[][] oldvars = vars.keys.dup;
        super.visit(p);
        vars = null;
        foreach( char[] v; oldvars ){
            vars[ v ] = true;
        }
    }
}

class FinallyBlockFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;
    int labelIdx = 0;
    PTypeInst retType;
    override void visit(PModule p){
        labelIdx = 0;
        super.visit(p);
    }
    override void visit(PInstanceInit p){
        PTypeInst bak = retType;
        retType = null;
        super.visit(p);
        retType = bak;
    }
    override void visit(PStaticCtor p){
        PTypeInst bak = retType;
        retType = null;
        super.visit(p);
        retType = bak;
    }
    override void visit(PCtor p){
        PTypeInst bak = retType;
        retType = null;
        super.visit(p);
        retType = bak;
    }
    override void visit(PMethodDef p){
        if( p.mIsNestedFunc ){
            return;
        }
        PTypeInst bak = retType;
        retType = p.mReturnType;
        super.visit(p);
        retType = bak;
    }
    override void visit(PStatTry p){
        super.visit(p);
        if( p.mFinally is null ){
            return;
        }

        char[] prefix = "tioport_";
        char[] state_pref = prefix ~ "stat_";

        bool hasRetVal = true;
        if( retType is null ){
            hasRetVal = false;
        }
        else if( retType.mTypeRef.mResolvedTypeDef is gBuildinTypeVoid && retType.mDimensions == 0 ){
            hasRetVal = false;
        }

        labelIdx++;
        PStatList slist = new PStatList;
        // create the state vars
        PLocalVarDef set = new PLocalVarDef( mModule );
        set.mName = Layouter( "{}set_{}", state_pref, labelIdx );
        set.mTypeInst = new PTypeInst( gBuildinTypeBoolean, 0, true );
        slist.mStats ~= set;

        PLocalVarDef val;
        if( hasRetVal ){
            val = new PLocalVarDef( mModule );
            val.mName = Layouter( "{}val_{}", state_pref, labelIdx );
            val.mTypeInst = retType.clone;
            slist.mStats ~= val;
        }

        PLocalVarDef exc = new PLocalVarDef( mModule );
        exc.mName = Layouter( "{}exc_{}", state_pref, labelIdx );
        exc.mTypeInst = new PTypeInst( gDObject, 0, true );
        slist.mStats ~= exc;

        // add try / catch
        PStatTry stry = new PStatTry;
        slist.mStats ~= stry;
        stry.mTodo = new PStatList;
        {
            // add the original try/catch into the try
            if( p.mHandlers.length == 0 ){
                stry.mTodo.mStats ~= p.mTodo.mStats;

                // append an empty statement with label
                PStatLabeled plbl = new PStatLabeled;
                plbl.mName = Layouter( "{}tryend_{}", prefix, labelIdx );

                // replace subsequent returns with storing state to the vars and make a goto to the label.
                ReturnReplacer returnReplacer = new ReturnReplacer( plbl.mName, set, val );
                stry.mTodo.accept( returnReplacer );

                if( returnReplacer.found ){
                    stry.mTodo.mStats ~= plbl;
                }
            }
            else{
                stry.mTodo.mStats ~= p;

                // replace return of todo, if found
                // append an empty statement with label
                {
                    PStatLabeled plbl = new PStatLabeled;
                    plbl.mName = Layouter( "{}tryend_{}", prefix, labelIdx );

                    ReturnReplacer returnReplacer = new ReturnReplacer( plbl.mName, set, val );
                    p.mTodo.accept( returnReplacer );
                    if( returnReplacer.found ){
                        p.mTodo.mStats ~= plbl;
                    }
                }

                // replace return of handlers, if found
                // append an empty statement with label
                {
                    PStatLabeled plbl = new PStatLabeled;
                    plbl.mName = Layouter( "{}catchend_{}", prefix, labelIdx );

                    ReturnReplacer returnReplacer = new ReturnReplacer( plbl.mName, set, val );
                    foreach( PStatCatch sc; p.mHandlers ){
                        sc.accept( returnReplacer );
                    }
                    if( returnReplacer.found ){
                        stry.mTodo.mStats ~= plbl;
                    }
                }
            }


        }
        // catch the uncaught exception and store it
        {
            PStatCatch scatch = new PStatCatch;
            PParameterDef caughtExc = new PParameterDef(mModule);
            caughtExc.mTypeInst = new PTypeInst( gDObject, 0, true );
            caughtExc.mName = Layouter( "{}caughtExc_{}", prefix, labelIdx );
            scatch.mParam = caughtExc;
            scatch.mTodo  = new PStatList;
            PExprAssign excAssign = new PExprAssign;
            excAssign.mOp = "=";

            excAssign.mLExpr = new PExprVarRef( exc );
            excAssign.mLExpr.mResolvedTypeInst = exc.mTypeInst.clone;

            excAssign.mRExpr = new PExprVarRef( caughtExc );
            excAssign.mRExpr.mResolvedTypeInst = caughtExc.mTypeInst.clone;

            excAssign.mAsStatement = true;
            excAssign.mResolvedTypeInst = caughtExc.mTypeInst.clone;
            scatch.mTodo.mStats ~= excAssign;
            stry.mHandlers ~= scatch;
        }

        // move the finally "block" to the new stat list
        slist.mStats ~= p.mFinally.mTodo;
        p.mFinally = null;

        // check exception => throw
        {
            PStatIf sif = new PStatIf;
            slist.mStats ~= sif;
            PExprBinary test = new PExprBinary;
            test.mOp = "!is";
            test.mLExpr = new PExprVarRef( exc );
            test.mRExpr = makeLiteralNull();
            test.mResolvedTypeInst = new PTypeInst( gBuildinTypeBoolean, 0, true );
            sif.mCond = test;

            PStatThrow sthrow = new PStatThrow;
            sthrow.mExpr = new PExprVarRef( exc );
            sthrow.mExpr.mResolvedTypeInst = exc.mTypeInst.clone;
            sif.mTCase = sthrow;
        }

        // check return
        {
            PStatIf sif = new PStatIf;
            slist.mStats ~= sif;
            sif.mCond = new PExprVarRef( set );

            PStatReturn sret = new PStatReturn;
            if( hasRetVal ){
                sret.mValue = new PExprVarRef( val );
            }
            sif.mTCase = sret;
        }

        p.mPartParent.exchangeStat( p, slist );
    }

    class ReturnReplacer : PartTraversVisitor {
        alias PartTraversVisitor.visit visit;
        PLocalVarDef set;
        PLocalVarDef val;
        char[] labelName;
        bool found;

        public this( char[] aEndLabelName, PLocalVarDef set, PLocalVarDef val ){
            labelName = aEndLabelName;
            this.set = set;
            this.val = val;
        }

        override void visit(PMethodDef p){
            if( p.mIsNestedFunc ){
                return;
            }
            super.visit(p);
        }
        override void visit(PStatReturn p){
            super.visit(p);

            PStatList slist = new PStatList;

            {
                PExprAssign excAssign = new PExprAssign;
                excAssign.mOp = "=";
                excAssign.mLExpr = new PExprVarRef( set );
                excAssign.mRExpr = makeLiteralBool( true );
                excAssign.mAsStatement = true;
                excAssign.mResolvedTypeInst = set.mTypeInst.clone;
                slist.mStats ~= excAssign;
            }
            if( val !is null ){
                PExprAssign excAssign = new PExprAssign;
                excAssign.mOp = "=";

                excAssign.mLExpr = new PExprVarRef( val );
                excAssign.mRExpr = p.mValue;
                excAssign.mAsStatement = true;
                excAssign.mResolvedTypeInst = val.mTypeInst.clone;
                slist.mStats ~= excAssign;
            }

            PStatGoto sgoto = new PStatGoto;
            sgoto.mName = labelName.dup;
            slist.mStats ~= sgoto;

            p.mPartParent.exchangeStat( p, slist );
            found = true;
        }
    }
}

class EvalOrderFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    int labelIdx = 0;

    override void visit(PModule p){
        labelIdx = 0;
        super.visit(p);
    }
    override void visit(PExprBinary p){
        super.visit(p);
        if( p.mOp != "|" && p.mOp != "&" && p.mOp != "^" ){
            return;
        }
        auto finderA = new ComplexFinder();
        auto finderB = new ComplexFinder();
        p.mLExpr.accept( finderA );
        p.mRExpr.accept( finderB );
        if( !( finderA.isComplex && finderB.isComplex ) ){
            return;
        }
        PExprMethodCall ecall = new PExprMethodCall();
        bool isLong = false;
        if( p.mResolvedTypeInst.mTypeRef.mResolvedTypeDef is gBuildinTypeLong ){
            isLong = true;
        }
        switch( p.mOp ){
        case "|": ecall.mResolvedCallable = isLong ? gFncEvalOrderedOrL  : gFncEvalOrderedOrI ; break;
        case "&": ecall.mResolvedCallable = isLong ? gFncEvalOrderedAndL : gFncEvalOrderedAndI; break;
        case "^": ecall.mResolvedCallable = isLong ? gFncEvalOrderedXorL : gFncEvalOrderedXorI; break;
        default:
        }
        ecall.mName = ecall.mResolvedCallable.mName;
        ecall.mResolvedTypeInst = new PTypeInst( isLong ? gBuildinTypeLong : gBuildinTypeInt, 0, true );
        ecall.mTrgExpr = null;
        ecall.mArguments ~= p.mLExpr;
        ecall.mArguments ~= p.mRExpr;
        ecall.mAsStatement = p.mAsStatement;
        p.mPartParent.exchangeExpr( p, ecall );
    }

    class ComplexFinder : PartTraversVisitor {
        alias PartTraversVisitor.visit visit;
        bool  isComplex = false;
        override void visit(PExprNew p){
            isComplex = true;
        }
        override void visit(PExprNewArray p){
            isComplex = true;
        }
        override void visit(PExprNewAnon p){
            isComplex = true;
        }
        override void visit(PExprMethodCall p){
            if( PMethodDef mth = cast(PMethodDef)p.mResolvedCallable ){
                if( mth in indexFnc ){
                    return;
                }
            }
            isComplex = true;
        }
        override void visit(PExprFncRef p){
            isComplex = true;
        }
        override void visit(PVarInitArray p){
            isComplex = true;
        }
        override void visit(PExprAssign p){
            isComplex = true;
        }
        override void visit(PExprUnary p){
            switch( p.mOp ){
            case "++":
            case "--":
                isComplex = true;
                break;
            default:
            }
        }
    }

}

/**
  Generate D-helper methods for all methods having String and/or arrays in their arguments list or such a return type.
  The generated methods name start with 'dh_' (D Helper)
  This pattern is applied for all classes and interfaces.
  exceptions are:
  */
class DHelperFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    bool isStringOrArray( PTypeInst aTi ){
        PTypeDef td = aTi.mTypeRef.mResolvedTypeDef;
        if( isArrayTypeDef( td )){
            return true;
        }
        if( td is gTypeJavaLangString ){
            return true;
        }
        return false;
    }

    PMethodDef generateHelper( PMethodDef aMethod, bool intf ){
        PMethodDef res = aMethod.cloneMethodDefDeclaration();
        res.mName = "dh_" ~ aMethod.mName;

        // Change signature types to D arrays
        PTypeInst changeToDArrayType( PTypeInst ti ){
            if( !isStringOrArray( ti )){
                return ti;
            }
            PTypeDef td = ti.mTypeRef.mResolvedTypeDef;
            if( td is gTypeJavaLangString ){
                return new PTypeInst( gBuildinTypeCharD, 1, true );
            }
            // is array
            int dim;
            PTypeInst cur = ti;
            while( cur.mTypeRef.mGenericArgs.length == 1 ){
                dim ++;
                cur = cur.mTypeRef.mGenericArgs[0];
            }
            PTypeDef arrTd = cur.mTypeRef.mResolvedTypeDef;
            if( arrTd is gTypeJavaLangString ){
                // char[] needs one dim more
                dim++;
                arrTd = gBuildinTypeCharD;
            }
            return new PTypeInst( arrTd, dim, true );
        }
        res.mReturnType = changeToDArrayType( res.mReturnType );
        foreach ( uint idx, PParameterDef pd; res.mParams) {
            pd.mTypeInst = changeToDArrayType( pd.mTypeInst );
        }

        if( intf ){
            return res;
        }

        // if this is an abstract method, now it isn't
        // we add the implementation right here.
        res.mModifiers.mAbstract = false;

        PStatList sl = new PStatList;
        res.mStatList = sl;

        PExprMethodCall ecall = new PExprMethodCall;
        ecall.mTrgExpr = null;//new PExprVarRef( parthis );

        ecall.mResolvedCallable = aMethod;
        ecall.mName             = aMethod.mName.dup;
        ecall.mResolvedTypeInst = aMethod.mReturnType;

        PExpr convertJ2D( PExpr arg ){
            PExprMethodCall econv = new PExprMethodCall;
            econv.mTrgExpr = null;

            econv.mResolvedCallable = gFncDHConvertJ2D;
            econv.mName             = gFncDHConvertJ2D.mName.dup;
            econv.mResolvedTypeInst = gFncDHConvertJ2D.mReturnType;
            econv.mArguments ~= arg;
            econv.mTypeArguments ~= new PExprTypeInst( arg.mResolvedTypeInst );
            econv.mTypeArguments ~= new PExprTypeInst( changeToDArrayType( arg.mResolvedTypeInst ));
            return econv;
        }
        PExpr convertD2J( PExpr arg ){
            PExprMethodCall econv = new PExprMethodCall;
            econv.mTrgExpr = null;

            econv.mResolvedCallable = gFncDHConvertD2J;
            econv.mName             = gFncDHConvertD2J.mName.dup;
            econv.mResolvedTypeInst = gFncDHConvertD2J.mReturnType;
            econv.mArguments ~= arg;
            econv.mTypeArguments ~= new PExprTypeInst( changeToDArrayType( arg.mResolvedTypeInst ));
            econv.mTypeArguments ~= new PExprTypeInst( arg.mResolvedTypeInst );
            return econv;
        }
        // args to the call.
        foreach (PParameterDef pd; aMethod.mParams) {
            if( isStringOrArray( pd.mTypeInst )){
                ecall.mArguments ~= convertD2J( new PExprVarRef(pd) );
            }
            else{
                ecall.mArguments ~= new PExprVarRef(pd);
            }
        }

        if( res.mReturnType.mTypeRef.mResolvedTypeDef is gBuildinTypeVoid ){
            ecall.mAsStatement = true;
            sl.mStats ~= ecall;
        }
        else{
            PStatReturn ret = new PStatReturn;
            if( isStringOrArray( ecall.mResolvedTypeInst )){
                ret.mValue = convertJ2D( ecall );
            }
            else{
                ret.mValue = ecall;
            }
            sl.mStats ~= ret;
        }
        return res;
    }

    PMethodDef[] generateHelpers( PMethodDef[] aMethods, bool intf ){
        PMethodDef[] res = aMethods.dup;

        foreach( PMethodDef mth; aMethods ){
            bool makeHelper = false;
            if( mth.mModifiers.mProtection != Protection.PUBLIC ){
                continue;
            }
            if( locatePattern( mth.mName, "tioport_caller_" ) == 0 ){
                continue;
            }
            if( isStringOrArray( mth.mReturnType )){
                makeHelper = true;
            }
            foreach( PParameterDef pd; mth.mParams ){
                if( isStringOrArray( pd.mTypeInst )){
                    makeHelper = true;
                }
            }
            if( makeHelper ){
                res ~= generateHelper( mth, intf );
            }
        }
        return res;
    }

    override void visit(PClassDef p){
        // also abstract method shall have a full implemented help,
        // so a user do not need to implement the helpers.
        p.mMethods = generateHelpers( p.mMethods, false );
    }
    override void visit(PInterfaceDef p){
        p.mMethods = generateHelpers( p.mMethods, true );
    }
}

class PullinDerivedMethodsFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    alias HashSet!(AliasFunction) TSetAFunc;
    alias HashSet!(char[]) TSetStr;


    override void visit(PClassDef p){
        super.visit(p);

        if (p.mSuperClass is null) {
            return;
        }

        PClassDef sc    = cast(PClassDef)p.mSuperClass.mResolvedTypeDef;
        TSetStr   names = new TSetStr;
        //TSetAFunc  funcs = new TSetAFunc;

        while (sc !is null) {
            char[][] newNames;
            foreach (PMethodDef m; sc.mMethods) {
                if (m.mModifiers.mProtection != Protection.PRIVATE) {
                    if (!names.contains(m.mName)) {
                        assert(m.mName !is null, scopeStackToUtf8());
                        names.add(m.mName.dup);
                        newNames ~= m.mName;
                    }
                }
            }
            foreach (char[] newName; newNames) {
                foreach (PMethodDef m; p.mMethods) {
                    if (m.mName == newName && m.mModifiers.mProtection != Protection.PRIVATE) {
                        AliasFunction a = new AliasFunction;
                        a.mClassDef = sc;
                        a.mName     = newName;
                        p.mAliases ~= a;
                        break;
                    }
                }
            }
            if (sc.mSuperClass is null) {
                break;
            }
            sc = cast(PClassDef)sc.mSuperClass.mResolvedTypeDef;
        }

        //// Find all method declarations that are required from the Interfaces
        //names = new TSetStr;
        //void collectMethods( PInterfaceDef i ){
        //    assert( i !is null, scopeStackToUtf8 );
        //    foreach( PMethodDef md; i.mMethods ){
        //        names.include( md.mName.dup );
        //    }
        //    foreach( PTypeRef ci; i.mSuperIfaces ){
        //        collectMethods( cast(PInterfaceDef) ci.mResolvedTypeDef );
        //    }
        //}
        //foreach( PTypeRef ci; p.mSuperIfaces ){
        //    collectMethods( cast(PInterfaceDef) ci.mResolvedTypeDef );
        //}

        //// Remove the ones that are implemented in this class.
        //foreach( PMethodDef md; p.mMethods ){
        //    if (md.mModifiers.mProtection != Protection.PRIVATE) {
        //        names.exclude( md.mName );
        //    }
        //}

        //// Now find the implementation of the remaining ones in the base classes
        //if( names.size() > 0 ){
        //    sc    = cast(PClassDef)p.mSuperClass.mResolvedTypeDef;
        //    while (sc !is null) {
        //        foreach (PMethodDef m; sc.mMethods) {
        //            if (m.mModifiers.mProtection != Protection.PRIVATE && names.contains(m.mName)) {
        //                names.exclude(m.mName);

        //                AliasFunction a = new AliasFunction;
        //                a.mClassDef = sc;
        //                a.mName     = m.mName.dup;
        //                p.mAliases ~= a;
        //            }
        //        }
        //        if (sc.mSuperClass is null) {
        //            break;
        //        }
        //        sc = cast(PClassDef)sc.mSuperClass.mResolvedTypeDef;
        //    }
        //}
    }
}


class ImportOnlyNeededFixer : PartTraversVisitor {
    alias      PartTraversVisitor.visit visit;

    PModule[]  mModules;

    override void visit(PModule p){
        auto finder = new ReferencedModulesFinder();

        p.accept(finder);
        auto     it = finder.mModules.elements();
        PModule[char[]] map;
        while (it.more()) {
            PModule mod = it.get();
            map[mod.getFqn()] = mod;
        }
        char[][] sortedKeys = map.keys.sort;
        foreach (char[] name; sortedKeys) {
            PModule mod = map[name];
            if (mod !is p) {
                p.mImportedModules ~= mod;
            }
        }
    }
    class ReferencedModulesFinder : PartTraversVisitor {
        alias   PartTraversVisitor.visit visit;
        alias   HashSet!(PModule) TModSet;
        TModSet mModules;


        this(){
            mModules = new TModSet;
        }
        private void include(PModule p){
            if( p is gModDObject ){
                return;
            }

            assert(p !is null, scopeStackToUtf8());
            mModules.add(p);
        }
        private void include(PTypeDef p){
            assert(p !is null, scopeStackToUtf8());
            //version(DEBUG_IMPORTS) Stdout.formatln( "line {0}, {1}", __LINE__, p.mName );
            include(p.mModule);
        }
        private void include(PTypeInst p){
            assert(p !is null, scopeStackToUtf8());
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p.mTypeRef.mResolvedTypeDef);
        }
        private void include(PParameterDef p){
            assert(p !is null, scopeStackToUtf8());
            assert(p.mTypeInst !is null, p.mName ~ "->" ~ scopeStackToUtf8());
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p.mTypeInst);
        }
        private void include(PExpr p){
            assert(p !is null, scopeStackToUtf8());
            assert(p.mResolvedTypeInst !is null, "->" ~ scopeStackToUtf8());
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p.mResolvedTypeInst);
        }
        override void visit(PExprVarRef p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p);
            if( p.mFromTypeDef !is null ){
                include(p.mFromTypeDef);
            }
            include(p.mParameterDef);
        }
        override void visit(PExprInstanceof p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p);
            include( p.mTypeInst );
        }
        override void visit(PExprTypecast p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p);
            //assert(p.mTypeInst !is null, p.toUtf8 ~ "->" ~ scopeStackToUtf8());
            include( p.mTypeInst );
        }
        override void visit(PExprFncRef p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            //include(p);
            //include(p.mParameterDef);
        }
        override void visit(PExprTypeInst p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p);
        }
        override void visit(PParameterDef p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}, {1}", __LINE__, p.mName );
            include(p);
            include(p.mModule);
        }
        override void visit(PLocalVarDef p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}, {1}", __LINE__, p.mName );
            include(p);
        }
        override void visit(PFieldDef p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}, {1}", __LINE__, p.mName );
            include(p);
        }
        override void visit(PMethodDef p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}, {1}", __LINE__, p.mName );
            //assert(p.mReturnType !is null, p.toUtf8 ~ "->" ~ scopeStackToUtf8());
            include(p.mReturnType);
        }
        override void visit(PExprMethodCall p){
            super.visit(p);
            if (p.mTrgExpr !is null) {
                version(DEBUG_IMPORTS) Stdout.formatln( "line {0}, {1}", __LINE__, p.mName );
                //assert(p.mTrgExpr !is null, p.toUtf8 ~ "->" ~ scopeStackToUtf8());
                include(p.mTrgExpr);
            }
        }
        override void visit(PExprNew p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p);
        }
        override void visit(PExprNewAnon p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p);
        }
        override void visit(PExprNewArray p){
            super.visit(p);
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            include(p);
        }
        override void visit(PInterfaceDef p){
            super.visit(p);
            foreach (PTypeRef tr; p.mSuperIfaces) {
                version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
                include(tr.mResolvedTypeDef);
            }
        }
        override void visit(PClassDef p){
            if( p is gDObject ){
                return;
            }

            super.visit(p);
            foreach (PTypeRef tr; p.mSuperIfaces) {
                version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
                include(tr.mResolvedTypeDef);
            }
            version(DEBUG_IMPORTS) Stdout.formatln( "line {0}", __LINE__ );
            if (p.mSuperClass !is null) {
                include(p.mSuperClass.mResolvedTypeDef);
            }
        }
    }
}

class StaticCtorFixer : PartTraversVisitor {
    alias      PartTraversVisitor.visit visit;
    PModule    mStaticCtorMod;
    PMethodDef mCaller;


    this(PModule aStaticCtorMod){
        mStaticCtorMod = aStaticCtorMod;

        mCaller                        = new PMethodDef;
        mCaller.mName                  = "callAllStaticCtors";
        mCaller.mModifiers             = new PModifiers;
        mCaller.mModifiers.mProtection = Protection.PUBLIC;
        mCaller.mReturnType            = new PTypeInst(gBuildinTypeVoid, 0, true);
        mCaller.mParams                = null;
        mCaller.mStatList              = new PStatList;

        mStaticCtorMod.mModuleMethods ~= mCaller;
    }

    override void visit(PClassDef p){
        super.visit(p);

        // because of ClassRegistrationFixer we have 1 static ctor
        if( p.mStaticCtors.length < 1 ){
            Stdout.formatln( " no static ctors {}",p.toUtf8 );
            return;
        }

        PStaticCtor ctor = p.mStaticCtors[0];
        p.mStaticCtors = null;

        PMethodDef mdef = new PMethodDef;
        mdef.mName                  = "static_this";
        mdef.mModifiers             = new PModifiers;
        mdef.mModifiers.mProtection = Protection.PUBLIC;
        mdef.mModifiers.mStatic     = true;
        mdef.mReturnType            = new PTypeInst(gBuildinTypeVoid, 0, true);
        mdef.mParams                = null;
        mdef.mStatList              = ctor.mStatList;
        p.mMethods ~= mdef;


        PExprMethodCall ecall = new PExprMethodCall;
        ecall.mAsStatement      = true;
        ecall.mName             = mdef.mName.dup;
        ecall.mResolvedCallable = mdef;
        ecall.mResolvedTypeInst = mdef.mReturnType;
        PExprTypeInst ti = new PExprTypeInst();
        ti.mResolvedTypeInst = new PTypeInst(p, 0, false);
        ecall.mTrgExpr       = ti;

        mCaller.mStatList.mStats ~= ecall;
    }
}

class ClassRegistrationFixer : PartTraversVisitor {
    alias      PartTraversVisitor.visit visit;
    PMethodDef mRegFunc;

    PMethodDef mMthRegClass;
    PMethodDef mMthRegField;
    PMethodDef mMthRegMethod;
    PMethodDef mMthRegCtor;

    PClassDef  mClassField;
    PCtor      mFieldCtor;

    PClassDef  mClassMethod;
    PClassDef  mClassConstructor;

    public this(){
        mMthRegClass  = cast(PMethodDef) gClsJavaLangClass.mAccessibleMethods[ "regClass" ][0];
        assert( mMthRegClass !is null );
        mMthRegField  = cast(PMethodDef) gClsJavaLangClass.mAccessibleMethods[ "regField" ][0];
        assert( mMthRegField !is null );
        mMthRegMethod = cast(PMethodDef) gClsJavaLangClass.mAccessibleMethods[ "regMethod" ][0];
        assert( mMthRegMethod !is null );
        mMthRegCtor   = cast(PMethodDef) gClsJavaLangClass.mAccessibleMethods[ "regConstructor" ][0];
        assert( mMthRegCtor !is null );
        PPackage refl = packJavaLang.findChildPackage("reflect");
        mClassField = cast(PClassDef) refl.findChildTypeDef( "Field" );
        assert(mClassField !is null );

        // change the Class parameter to classinfo

        {
            auto ctor = mClassField.mCtors[0];
            auto typeClass = ctor.mParams[2];
            typeClass.mTypeInst = new PTypeInst( gClsTypeInfo, 0, true );
        }

        mClassMethod = cast(PClassDef) refl.findChildTypeDef( "Method" );
        assert(mClassMethod !is null );
        mClassConstructor = cast(PClassDef) refl.findChildTypeDef( "Constructor" );
        assert(mClassConstructor !is null );
    }

    override void visit(PClassDef p){
        super.visit(p);

        // if there is no static ctor, add one to make the registration
        if (p.mStaticCtors.length == 0 ) {

            PStaticCtor ctor = new PStaticCtor;
            ctor.mModifiers         = new PModifiers;
            ctor.mModifiers.mStatic = true;
            ctor.mStatList          = new PStatList;
            p.mStaticCtors ~= ctor;
        }
        assert( p.mStaticCtors.length == 1, Layouter("{} static ctors in {}", p.mStaticCtors.length, p.toUtf8 ));
        PStaticCtor sctor = p.mStaticCtors[0];

        // add this
        // { // a separated block in case there are static fields initialized called 'clazz'.
        PStatList slist = new PStatList;
        sctor.mStatList.mStats = [ slist ] ~ sctor.mStatList.mStats;
        // add the statement list as the first statement.
        // the class registraction shall happen before everything,
        // because is possible the static ctor needs to reflect own methods.

        // -----------------------------
        // Class clazz = dejavu.lang.Class.Class.regClass( fqn.classinfo );
        PLocalVarDef varClazz = new PLocalVarDef( p.mModule );
        varClazz.mName = "tioport_reg_clazz";
        varClazz.mTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
        //varClazz.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );

        PVarInitExpr varClazzInit = new PVarInitExpr;
        varClazzInit.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
        varClazz.mInitializer = varClazzInit;

        {
            PExprMethodCall callRegClass = new PExprMethodCall();
            callRegClass.mResolvedCallable = mMthRegClass;
            callRegClass.mAsStatement      = false;
            callRegClass.mName             = mMthRegClass.mName.dup;
            callRegClass.mResolvedTypeInst = mMthRegClass.mReturnType;
            PExprTypeInst trg = new PExprTypeInst;
            trg.mResolvedTypeInst = new PTypeInst(gClsJavaLangClass, 0, false);
            callRegClass.mTrgExpr       = trg;
            varClazzInit.mExpr = callRegClass;

            PExprMethodCall etypeid = new PExprMethodCall;
            etypeid.mResolvedCallable = gFncClassInfo;
            PExprTypeInst   ecallTrg = new PExprTypeInst;
            ecallTrg.mResolvedTypeInst = new PTypeInst(p, 0, false);
            etypeid.mTrgExpr = ecallTrg;
            etypeid.mResolvedTypeInst = new PTypeInst(gClsTypeInfo, 0, false);

            callRegClass.mArguments ~= etypeid;
        }

        slist.mStats ~= varClazz;

        // -----------------------------
        // clazz.regField( new dejavu.lang.reflect.Field(
        //   /* declaring class      */ clazz,
        //   /* field name           */ new String( w"fieldname" ),
        //   /* type class           */ null,
        //   /* modifiers            */ 0,
        //   /* slot                 */ fieldname.offsetof,
        //   /* signature            */ new String( w"I" ),
        //   /* annotations          */ null );
        foreach( PFieldDef fd; p.mFields ){
            PExprNew fldCtor = new PExprNew();
            fldCtor.mTypeRef       = new PTypeRef;
            fldCtor.mTypeRef.mResolvedTypeDef = mClassField;
            fldCtor.mResolvedTypeInst = new PTypeInst(mClassField, 0, true);

            // declaring class
            {
                PExprVarRef clazzRef = new PExprVarRef();
                clazzRef.mParameterDef = varClazz;
                clazzRef.mFromTypeDef = null; // local var
                clazzRef.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
                fldCtor.mArguments ~= clazzRef;
            }
            // field name
            {
                fldCtor.mArguments ~= makeString( fd.mName );
            }
            // type Class
            {
                PTypeDef td = fd.mTypeInst.mTypeRef.mResolvedTypeDef;
                if( cast(PBuildinType)td !is null ){
                    fldCtor.mArguments ~= makeLiteralNull();
                }
                else{
                    fldCtor.mArguments ~= makeClassInfo( fd.mTypeInst.mTypeRef.mResolvedTypeDef );
                }
            }
            // modifiers
            {
                fldCtor.mArguments ~= makeLiteralIntegerHex( fd.mModifiers.asInt() );
            }
            // slot
            {
                if( fd.mModifiers.isStatic ){
                    PExprVarRef vref = new PExprVarRef;
                    vref.mParameterDef = fd;
                    vref.mFromTypeDef = p;
                    vref.mGetAddress = true;
                    vref.mResolvedTypeInst = new PTypeInst( gBuildinTypeUInt, 0, true );
                    fldCtor.mArguments ~= vref;

                }
                else{
                    PExprVarRef vref = new PExprVarRef;
                    vref.mParameterDef = fd;
                    vref.mFromTypeDef = null;//p;
                    vref.mOffsetOf = true;
                    vref.mResolvedTypeInst = new PTypeInst( gBuildinTypeUInt, 0, true );
                    fldCtor.mArguments ~= vref;
                }
            }
            // signature
            {
                fldCtor.mArguments ~= makeString( getMangledType( fd.mTypeInst ) );
            }
            // annotations
            {
                fldCtor.mArguments ~= makeLiteralNull();
            }
            fldCtor.resolveCtor();

            // the regField call
            PExprMethodCall ecall = new PExprMethodCall;
            // trgExpr
            {
                PExprVarRef clazzRef = new PExprVarRef();
                clazzRef.mParameterDef = varClazz;
                clazzRef.mFromTypeDef = null; //local var
                clazzRef.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
                ecall.mTrgExpr = clazzRef;
            }

            ecall.mResolvedCallable = mMthRegField;
            ecall.mAsStatement      = true;
            ecall.mName             = mMthRegField.mName.dup;
            ecall.mResolvedTypeInst = mMthRegField.mReturnType;
            ecall.mArguments ~= fldCtor;
            slist.mStats ~= ecall;
        }
        // -----------------------------
        // clazz.addMethod( new dejavu.lang.reflect.Method (
        //   /* declaringClass       */ clazz,
        //   /* name                 */ new String( "name" ),
        //   /* parameterTypes       */ null,
        //   /* returnType           */ ???,
        //   /* checkedExceptions    */ null,
        //   /* modifiers            */ 0x00,
        //   /* slot                 */ ,
        //   /* signature            */ new String( "IILorg/eclipse/swt/SWT;",
        //   /* annotations          */ null,
        //   /* parameterAnnotations */ null,
        //   /* annotationDefault    */ null ));
        foreach( PMethodDef mth; p.mMethods ){
            if( mth.mModifiers.mNative ){
                continue;
            }
            if( mth.mModifiers.mProtection == Protection.PRIVATE ){
                continue;
            }

            // Create the caller function
            PMethodDef caller;

            if( !mth.mModifiers.mStatic )
            {
                // int tioport_caller_Fnc( MyObject tioport_callerparam_this, .... ){
                //     return tioport_caller_param_this.Fnc( ... );
                // }
                caller = new PMethodDef;
                caller.mName = "tioport_caller_" ~ mth.mName;

                PParameterDef parthis = new PParameterDef( mModule );
                parthis.mName = "tioport_callerparam_this";
                parthis.mTypeInst = new PTypeInst( p, 0, true );
                caller.mParams ~= parthis;
                caller.mParams ~= mth.mParams.dup;

                caller.mModifiers = new PModifiers;

                caller.mReturnType = mth.mReturnType;
                caller.mStatList = new PStatList;

                PExprMethodCall ecall = new PExprMethodCall;
                ecall.mTrgExpr = new PExprVarRef( parthis );

                ecall.mResolvedCallable = mth;
                ecall.mName             = mth.mName.dup;
                ecall.mResolvedTypeInst = mth.mReturnType;

                // append the addtional args to the call.
                foreach (PParameterDef pd; mth.mParams) {
                    ecall.mArguments ~= new PExprVarRef(pd);
                }

                if( caller.mReturnType.mTypeRef.mResolvedTypeDef is gBuildinTypeVoid ){
                    ecall.mAsStatement = true;
                    caller.mStatList.mStats ~= ecall;
                }
                else{
                    PStatReturn ret = new PStatReturn;
                    ret.mValue = ecall;
                    caller.mStatList.mStats ~= ret;
                }
                caller.mModifiers.mStatic = true;
                p.mMethods ~= caller;
            }


            PExprNew fldCtor = new PExprNew();
            fldCtor.mTypeRef       = new PTypeRef;
            fldCtor.mTypeRef.mResolvedTypeDef = mClassMethod;
            fldCtor.mResolvedTypeInst = new PTypeInst(mClassMethod, 0, true);
            //   /* declaringClass       */ clazz,
            {
                PExprVarRef clazzRef = new PExprVarRef();
                clazzRef.mParameterDef = varClazz;
                clazzRef.mFromTypeDef = null; // local var
                clazzRef.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
                fldCtor.mArguments ~= clazzRef;
            }
            //   /* name                 */ new String( "name" ),
            {
                fldCtor.mArguments ~= makeString( mth.mName );
            }
            //   /* parameterTypes       */ null,
            {
                fldCtor.mArguments ~= makeLiteralNull();
            }
            //   /* returnType           */ ???,
            {
                fldCtor.mArguments ~= makeString( getMangledType( mth.mReturnType ) );
            }
            //   /* checkedExceptions    */ null,
            {
                fldCtor.mArguments ~= makeLiteralNull();
            }
            //   /* modifiers            */ 0x00,
            {
                int mod = mth.mModifiers.asInt();
                fldCtor.mArguments ~= makeLiteralIntegerHex( mod );
            }
            //   /* slot                 */ ,
            {
                PMethodDef calledMeth = ( mth.mModifiers.mStatic ) ? mth : caller;
                PExprFncRef vref = new PExprFncRef;
                vref.mMethodDef = calledMeth;
                vref.mNoFqn = true;
                vref.mResolvedTypeInst = new PTypeInst( gBuildinTypeInt, 0, true );

                PExprTypecast sigcast = new PExprTypecast();
                sigcast.mExpr             = vref;

                PFuncTypeDef fnc = new PFuncTypeDef( mModule );
                fnc.mReturnType = calledMeth.mReturnType;
                fnc.mParams = calledMeth.mParams.dup;
                sigcast.mTypeInst         = new PTypeInst( fnc, 0, true );

                sigcast.mResolvedTypeInst = sigcast.mTypeInst.clone();

                PExprTypecast n = new PExprTypecast();
                n.mExpr             = sigcast;
                n.mTypeInst         = new PTypeInst( gBuildinTypeInt, 0, true );
                n.mResolvedTypeInst = new PTypeInst( gBuildinTypeInt, 0, true );
                fldCtor.mArguments ~= n;
            }
            //   /* signature            */ new String( "IILorg/eclipse/swt/SWT;",
            {
                char[] sig;
                foreach( PParameterDef pd; mth.mParams ){
                    sig ~= getMangledType( pd.mTypeInst );
                }
                fldCtor.mArguments ~= makeString( sig );
            }
            //   /* annotations          */ null,
            {
                fldCtor.mArguments ~= makeLiteralNull();
            }
            //   /* parameterAnnotations */ null,
            {
                fldCtor.mArguments ~= makeLiteralNull();
            }
            //   /* annotationDefault    */ null ));
            {
                fldCtor.mArguments ~= makeLiteralNull();
            }
            fldCtor.resolveCtor();

            // the regMethod call
            PExprMethodCall ecall = new PExprMethodCall;
            // trgExpr
            {
                PExprVarRef clazzRef = new PExprVarRef();
                clazzRef.mParameterDef = varClazz;
                clazzRef.mFromTypeDef = null; //local var
                clazzRef.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
                ecall.mTrgExpr = clazzRef;
            }

            ecall.mResolvedCallable = mMthRegMethod;
            ecall.mAsStatement      = true;
            ecall.mName             = mMthRegMethod.mName.dup;
            ecall.mResolvedTypeInst = mMthRegMethod.mReturnType;
            ecall.mArguments ~= fldCtor;
            slist.mStats ~= ecall;
        }
        // public static Type tioport_factory( Arguments... ){
        //     return new Type( Arguments... );
        // }
        // -----------------------------
        // clazz.addCtor( new dejavu.lang.reflect.Constructor(
        //   /* declaring class      */ clazz,
        //   /* parameterTypes       */ null,
        //   /* checkedExceptions    */ null, 
        //   /* modifiers            */ 0,
        //   /* slot                 */ cast(int)cast( Type function( Arguments...)) & tioport_ctor,
        //   /* signature            */ new String( w"" ),
        //   /* annotations          */ null,
        //   /* parameterAnnotations */ null ));

        // if this is a non-static inner class, we do not need to register ctors
        if( p is mModuleTypeDef || p.mModifiers.mStatic ){
            foreach( PCtor ctor; p.mCtors ){
                if( p.mModifiers.mAbstract ){
                    continue;
                }

                // Create the factory function
                PMethodDef factory = new PMethodDef;

                {
                    factory.mName = "tioport_factory";
                    factory.mParams = ctor.mParams.dup;
                    factory.mReturnType = new PTypeInst( gBuildinTypePtr, 0, true );
                    factory.mStatList = new PStatList;

                    PExprNew newcall = new PExprNew;
                    newcall.mTypeRef       = new PTypeRef;
                    newcall.mTypeRef.mResolvedTypeDef = p;
                    newcall.mResolvedTypeInst = new PTypeInst(p, 0, true);

                    // append the addtional args to the call.
                    foreach (PParameterDef pd; factory.mParams) {
                        newcall.mArguments ~= new PExprVarRef(pd);
                    }
                    newcall.resolveCtor();

                    PExprTypecast cobj = new PExprTypecast();
                    cobj.mExpr             = newcall;
                    cobj.mTypeInst         = new PTypeInst( gIJObject, 0, true );
                    cobj.mResolvedTypeInst = new PTypeInst( gIJObject, 0, true );

                    PExprTypecast cptr = new PExprTypecast();
                    cptr.mExpr             = cobj;
                    cptr.mTypeInst         = new PTypeInst( gBuildinTypePtr, 0, true );
                    cptr.mResolvedTypeInst = new PTypeInst( gBuildinTypePtr, 0, true );

                    PStatReturn sret = new PStatReturn;
                    sret.mValue = cptr;
                    factory.mStatList.mStats ~= sret;

                    factory.mModifiers.mStatic = true;

                    p.mMethods ~= factory;
                }

                // Create the ctor registration, using the factory function
                PExprNew fldCtor = new PExprNew();
                fldCtor.mTypeRef       = new PTypeRef;
                fldCtor.mTypeRef.mResolvedTypeDef = mClassConstructor;
                fldCtor.mResolvedTypeInst = new PTypeInst(mClassConstructor, 0, true);

                //   /* declaring class      */ clazz,
                {
                    PExprVarRef clazzRef = new PExprVarRef();
                    clazzRef.mParameterDef = varClazz;
                    clazzRef.mFromTypeDef = null; // local var
                    clazzRef.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
                    fldCtor.mArguments ~= clazzRef;
                }
                //   /* parameterTypes       */ null,
                {
                    fldCtor.mArguments ~= makeLiteralNull();
                }
                //   /* checkedExceptions    */ null, 
                {
                    fldCtor.mArguments ~= makeLiteralNull();
                }
                //   /* modifiers            */ 0,
                {
                    int mod = factory.mModifiers.asInt();
                    fldCtor.mArguments ~= makeLiteralIntegerHex( mod );
                }
                //   /* slot                 */ cast(int)cast( Type function( Arguments...)) & tioport_ctor,
                {
                    PExprFncRef vref = new PExprFncRef;
                    vref.mMethodDef = factory;
                    vref.mNoFqn = true;
                    vref.mResolvedTypeInst = new PTypeInst( gBuildinTypeInt, 0, true );

                    PExprTypecast sigcast = new PExprTypecast();
                    sigcast.mExpr             = vref;

                    PFuncTypeDef fnc = new PFuncTypeDef( mModule );
                    fnc.mReturnType = factory.mReturnType;
                    fnc.mParams = factory.mParams.dup;
                    sigcast.mTypeInst         = new PTypeInst( fnc, 0, true );

                    sigcast.mResolvedTypeInst = sigcast.mTypeInst.clone();

                    PExprTypecast n = new PExprTypecast();
                    n.mExpr             = sigcast;
                    n.mTypeInst         = new PTypeInst( gBuildinTypeInt, 0, true );
                    n.mResolvedTypeInst = new PTypeInst( gBuildinTypeInt, 0, true );
                    fldCtor.mArguments ~= n;
                }
                //   /* signature            */ new String( w"" ),
                {
                    char[] sig;
                    foreach( PParameterDef pd; ctor.mParams ){
                        sig ~= getMangledType( pd.mTypeInst );
                    }
                    fldCtor.mArguments ~= makeString( sig );
                }
                //   /* annotations          */ null,
                {
                    fldCtor.mArguments ~= makeLiteralNull();
                }
                //   /* parameterAnnotations */ null ));
                {
                    fldCtor.mArguments ~= makeLiteralNull();
                }
                fldCtor.resolveCtor();

                // the regMethod call
                PExprMethodCall ecall = new PExprMethodCall;
                // trgExpr
                {
                    PExprVarRef clazzRef = new PExprVarRef();
                    clazzRef.mParameterDef = varClazz;
                    clazzRef.mFromTypeDef = null; //local var
                    clazzRef.mResolvedTypeInst = new PTypeInst( gClsJavaLangClass, 0, true );
                    ecall.mTrgExpr = clazzRef;
                }

                ecall.mResolvedCallable = mMthRegCtor;
                ecall.mAsStatement      = true;
                ecall.mName             = mMthRegCtor.mName.dup;
                ecall.mResolvedTypeInst = mMthRegCtor.mReturnType;
                ecall.mArguments ~= fldCtor;
                slist.mStats ~= ecall;
            }
        }
    }
}

class ReimplementIfaceFixer : PartTraversVisitor {
    alias      PartTraversVisitor.visit visit;

    override void visit(PClassDef p){
        super.visit(p);

        // abstract classes are not analysed.
        // unimplemented methods need an impl that is also checked from the java compiler
        // we are only looking for those that are derived directly from iface and not implemented in this class.
        if( p.mModifiers.mAbstract ){
            return;
        }

        // traverse all iface collect methods
        alias HashSet!(PMethodDef) TMethodDefs;

        TMethodDefs methods = new TMethodDefs;
        void recurseCollectIfaceMethods( PTypeRef[] superIfaces ){
            for( int i = 0; i < superIfaces.length; i++ ){
                if(PInterfaceDef iface = cast(PInterfaceDef) superIfaces[i].mResolvedTypeDef ){
                    if( iface is gIJObject ){
                        continue;
                    }
                    foreach( PMethodDef mth; iface.mMethods ){
                        methods.add( mth );
                    }
                    recurseCollectIfaceMethods( iface.mSuperIfaces );
                }
            }
        }
        recurseCollectIfaceMethods( p.mSuperIfaces );

        bool methodsEqual( PMethodDef a, PMethodDef b ){
            if( a.mName != b.mName ){
                return false;
            }
            if( a.mParams.length != b.mParams.length ){
                return false;
            }
            for( int i = 0; i < a.mParams.length; i++ ){
                if( a.mParams[i].mTypeInst != b.mParams[i].mTypeInst ){
                    return false;
                }
            }
            // no need to check the return type
            return true;
        }
        // find implementations in this class and keep the one without implementation
        TMethodDefs implementedMethods = new TMethodDefs;
        foreach( PMethodDef mth; p.mMethods ){
            auto it = methods.elements();
            while( it.more ){
                PMethodDef ifaceMeth = it.get();
                if( !methodsEqual( mth, ifaceMeth )){
                    continue;
                }
                implementedMethods.add( ifaceMeth );
            }
        }
        foreach( PMethodDef mth; implementedMethods ){
            methods.remove( mth );
        }

        // all remaining methods without implementation need a delegation into the super class
        auto it = methods.elements();
        while( it.more ){
            PMethodDef ifaceMeth = it.get();
            PMethodDef impl = ifaceMeth.cloneMethodDefDeclaration();
            impl.mModifiers.mAbstract = false;
            impl.mStatList = new PStatList;
            PExprMethodCall ecall = new PExprMethodCall;
            ecall.mName             = impl.mName.dup;


            foreach( PParameterDef pd; impl.mParams ){
                ecall.mArguments ~= new PExprVarRef(pd);
            }

            void resolveCall(){
                if( p.mSuperClass is null ){
                    return;
                }
                PClassDef cls = cast(PClassDef) p.mSuperClass.mResolvedTypeDef;
                while( cls !is null ){
                    foreach( PMethodDef mth; cls.mMethods ){
                        if( methodsEqual( mth, impl )){
                            ecall.mResolvedCallable = mth;

                            PExprVarRef svr = new PExprVarRef;
                            svr.mIsSuperRef = true;
                            svr.mParameterDef = cls.mThis;
                            svr.mFromTypeDef = cls;
                            svr.mResolvedTypeInst = new PTypeInst( cls, 0, true );
                            ecall.mTrgExpr = svr;

                            return;
                        }
                    }
                    if( cls.mSuperClass is null ){
                        break;
                    }
                    cls = cast(PClassDef)cls.mSuperClass.mResolvedTypeDef;
                }

                Stdout.formatln( "problem {0} method {1} class {2}", __LINE__, impl.mName, p.getFqn );
                foreach( PParameterDef pd; impl.mParams ){
                    Stdout.formatln( "problem param {0} {1} ", pd.mName, pd.mTypeInst.toUtf8() );
                }

            }
            resolveCall();
            assert( ecall.mResolvedCallable !is null );

            ecall.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);

            if( impl.mReturnType.mTypeRef.mResolvedTypeDef !is gBuildinTypeVoid ){
                PStatReturn sret = new PStatReturn;
                sret.mValue = ecall;
                impl.mStatList.mStats ~= sret;
            }
            else{
                ecall.mAsStatement = true;
                impl.mStatList.mStats ~= ecall;
            }
            p.mMethods ~= impl;
        }
    }
}

/**
  change all casts of array types into arraycast!(type) calls
  Find also all assignments, returns, methodparams that are related to arrays with not exactly the same dim or type.
  */
class AssignTypesFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    override void visit(PClassDef p){
        super.visit(p);
    }

    override void visit(PLocalVarDef p){
        super.visit(p);
        if (p.mInitializer !is null) {
            if (PVarInitExpr iex = cast(PVarInitExpr)p.mInitializer) {
                iex.mExpr = fix(iex.mExpr, p.mTypeInst);
            }
        }
    }

    override void visit(PExprNew p){
        super.visit(p);
        assert( p.mResolvedCtor !is null );
        fixArguments( p.mResolvedCtor.mParams, p.mArguments, "ctor" );
    }

    override void visit(PExprMethodCall p){
        super.visit(p);
        assert( p.mResolvedCallable !is null );
        if( PCtor cdef = cast(PCtor) p.mResolvedCallable ){
            fixArguments( cdef.mParams, p.mArguments, p.mName );
        }
    }

    private void fixArguments( PParameterDef[] pds, PExpr[] exs, char[] aName ){
        for( int i = 0; i < pds.length; i++ ){
            PParameterDef pd = pds[i];
            if( pd.mIsVariableLength ){
                for( int j = i; j < exs.length; j++ ){
                    exs[j] = fix(exs[j], pd.mTypeInst);
                }
            }
            else{
                assert( exs.length > i, Layouter( "{} {} {}", aName, exs.length, i ));
                exs[i] = fix(exs[i], pd.mTypeInst);
            }
        }
    }

    override void visit(PExprAssign p){
        super.visit(p);
        p.mRExpr = fix(p.mRExpr, p.mResolvedTypeInst);

        // Catch this case:
        // if( (a=true) && c ) ...
        // Error: '=' is not bool type
        // solution: change to ((a=true)==true) if parent is 'if', '&&', '||'
        if( p.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is gBuildinTypeBoolean ){
            return;
        }
        if( p.mResolvedTypeInst.mDimensions != 0 ){
            return;
        }

        PExprBinary getEqualsTrue(){
            PExprLiteral etrue = new PExprLiteral;
            etrue.mType             = LiteralType.LITERAL_true;
            etrue.mText             = "true";
            etrue.mResolvedTypeInst = new PTypeInst(gBuildinTypeBoolean, 0, true);

            PExprBinary res = new PExprBinary;
            res.mOp = "==";
            res.mRExpr = etrue;
            res.mLExpr = p;
            res.mResolvedTypeInst = p.mResolvedTypeInst.clone();
            return res;
        }

        PStatIf sif = cast( PStatIf ) p.mPartParent;
        if( sif !is null && sif.mCond is p ){
            p.mPartParent.exchangeExpr(p, getEqualsTrue());
            return;
        }

        PExprBinary ebin = cast( PExprBinary ) p.mPartParent;
        if( ebin !is null && ( ebin.mOp == "&&" || ebin.mOp == "||" )){
            p.mPartParent.exchangeExpr(p, getEqualsTrue());
            return;
        }
    }

    override void visit(PStatReturn p){
        super.visit(p);
        if (PMethodDef c = cast(PMethodDef)mCallable) {
            if (p.mValue !is null) {
                p.mValue = fix(p.mValue, c.mReturnType);
            }
        }
    }

    override void visit(PExprVarRef p){
        super.visit(p);
        // cast all uint to int, this is a special case for array "length"
        if( p.mParameterDef.mTypeInst.mTypeRef.mResolvedTypeDef is gBuildinTypeUInt && p.mResolvedTypeInst.mDimensions == 0 ){
            p.mPartParent.exchangeExpr( p, createTypecast( p, new PTypeInst( gBuildinTypeInt, 0, true )));
        }
    }
    override void visit(PExprNewArray p){
        super.visit(p);
        if( p.mInitializer !is null ){
            checkVarInitArray( p.mInitializer, p.mResolvedTypeInst );
        }
    }
    private void checkVarInitArray( PVarInitArray ia, PTypeInst outerTi ){
        PTypeInst ti = outerTi.clone;
        ti.mDimensions--;
        assert( ti.mDimensions >= 0 );
        foreach( PVarInitializer i; ia.mInitializers ){
            if( PVarInitExpr ie = cast(PVarInitExpr)i ){
                ie.mExpr = fix(ie.mExpr, ti );
            }
            else if( PVarInitArray ia2 = cast(PVarInitArray)i ){
                checkVarInitArray( ia2, ti );
            }
            else{
                assert( false );
            }
        }
    }
    override void visit(PExprTypecast p){
        super.visit(p);
        if( PExprMethodCall ecall = cast( PExprMethodCall ) p.mExpr ){
            if( ecall.mTrgExpr !is null && isArrayType( ecall.mTrgExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef ) ){
                //Stdout.formatln( "{}", scopeStackToUtf8 );
                return;
            }
        }
        //p.mExpr = checkArrayCreate(p.mExpr, p.mResolvedTypeInst);
        PTypeInst ti = p.mResolvedTypeInst;
        PExpr e = fix(p.mExpr, ti );
        if( e is p.mExpr ){
            if( e.mResolvedTypeInst.mDimensions != ti.mDimensions ) {
                return;
            }
            if ( e.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is ti.mTypeRef.mResolvedTypeDef ){
                return;
            }
            if( ti.mTypeRef.mResolvedTypeDef is gBuildinTypeChar ){
                e = createTypecast( e, ti );
            }
        }
        p.mPartParent.exchangeExpr( p, e);
    }

    override void visit(PExprInstanceof p){
        super.visit(p);
        PTypeDef td = p.mTypeInst.mTypeRef.mResolvedTypeDef;
        if( isArrayTypeDef( td )){
            PMethodDef instOfFnc = null;
            if( td is gJArrayBoolean ) instOfFnc = gFncArrayInstanceOfBoolean;
            if( td is gJArrayByte    ) instOfFnc = gFncArrayInstanceOfByte   ;
            if( td is gJArrayShort   ) instOfFnc = gFncArrayInstanceOfShort  ;
            if( td is gJArrayInt     ) instOfFnc = gFncArrayInstanceOfInt    ;
            if( td is gJArrayLong    ) instOfFnc = gFncArrayInstanceOfLong   ;
            if( td is gJArrayFloat   ) instOfFnc = gFncArrayInstanceOfFloat  ;
            if( td is gJArrayDouble  ) instOfFnc = gFncArrayInstanceOfDouble ;
            if( td is gJArrayChar    ) instOfFnc = gFncArrayInstanceOfChar   ;
            if( instOfFnc is null ) instOfFnc = gFncArrayInstanceOfJObject;
            PExprMethodCall ecall = new PExprMethodCall();
            ecall.mResolvedCallable = instOfFnc;
            ecall.mResolvedTypeInst = instOfFnc.mReturnType;
            ecall.mArguments ~= p.mExpr;
            ecall.mArguments ~= makeLiteralIntegerHex( p.mTypeInst.mDimensions );
            if( instOfFnc is gFncArrayInstanceOfJObject ){
                ecall.mArguments ~= makeClassInfo( p.mTypeInst.mTypeRef.mResolvedTypeDef );
            }
            p.mPartParent.exchangeExpr( p, ecall );
        }
    }

    private PExpr fix(PExpr e, PTypeInst ti){
        assert( e.mResolvedTypeInst.mDimensions == 0, Layouter( "{} {} {}", e.toUtf8 , e.mResolvedTypeInst.mDimensions, scopeStackToUtf8 ));
        assert( ti.mDimensions == 0 );
        // if all is equal, no cast necessary
        if(( e.mResolvedTypeInst.mDimensions == ti.mDimensions ) && ( e.mResolvedTypeInst.mTypeRef.mResolvedTypeDef is ti.mTypeRef.mResolvedTypeDef )){
            return e;
        }

        // null -> something
        if( e.mResolvedTypeInst.mTypeRef.mResolvedTypeDef is gBuildinTypeNull ){
            return createTypecast( e, ti );
        }

        if( ti.mTypeRef.mResolvedTypeDef is gBuildinTypePtr ){
            PExprMethodCall ecall = new PExprMethodCall;
            ecall.mResolvedCallable = gFncInternJniPtrCast;
            ecall.mResolvedTypeInst = ti.clone;
            ecall.mArguments ~= e;
            {
                auto eti = new PExprTypeInst;
                eti.mResolvedTypeInst = e.mResolvedTypeInst.clone;
                ecall.mTypeArguments ~= eti;
            }
            return ecall;
        }

        if( e.mResolvedTypeInst.mDimensions == 0 && ti.mDimensions == 0 ){
            // scalar, make cast
            return createTypecast( e, ti );
        }
        else{
            assert( false );
            //-FIXME how to handle???
            //- // array related, do an arraycast
            //- PExprMethodCall ecall = new PExprMethodCall;
            //- {
            //-     auto eti = new PExprTypeInst;
            //-     eti.mResolvedTypeInst = ti.clone;
            //-     ecall.mTypeArguments ~= eti;
            //- }
            //- {
            //-     auto eti = new PExprTypeInst;
            //-     eti.mResolvedTypeInst = e.mResolvedTypeInst.clone;
            //-     ecall.mTypeArguments ~= eti;
            //- }
            //- ecall.mArguments ~= e;
            //- ecall.mResolvedCallable = gFncArrayCast;
            //- ecall.mResolvedTypeInst = ti.clone;
            return e;
        }
    }
}

/**
  Remove typecasts in a statement
  */
class RemoveStatmentCastsFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    override void visit(PStatList p){
        super.visit(p);
        foreach( inout PStatement stat; p.mStats ){
            if( PExprTypecast tc = cast(PExprTypecast) stat ){
                stat = tc.mExpr;
            }
        }
    }
}

class ModuleInitFixer : PartTraversVisitor {
    alias PartTraversVisitor.visit visit;

    class InitCall {
        PMethodDef meth;
        PClassDef  cls;
    }
    InitCall[]   inits;
    PClassDef    clazz;

    PInterfaceDef intfModuleInit;
    public this(){
        intfModuleInit = new PInterfaceDef( gModIntern );
        intfModuleInit.mName = "TioPort_IModuleInit";
        gModIntern.mTypeDefs ~= intfModuleInit;
    }

    override void visit( PModule p ){

        if( p.mIsStub || p.mIsNowrite ){
            return;
        }

        inits = null;
        super.visit( p );

        // Generate the class and add to the module
        PClassDef res = new PClassDef( p );
        p.mTypeDefs ~= res;

        // private class
        res.mModifiers = new PModifiers;
        res.mModifiers.mProtection = Protection.PRIVATE;
        res.mName      = "TioPort_ModuleInit";

        // implements TioPort_IModuleInit
        PTypeRef tr = new PTypeRef;
        tr.mResolvedTypeDef = intfModuleInit;
        res.mSuperIfaces ~= tr;

        // create/implement the static_this method
        PMethodDef mth = new PMethodDef();
        res.mMethods ~= mth;

        mth.mName = "static_this";
        mth.mModifiers = new PModifiers;

        // return type
        mth.mReturnType = new PTypeInst( gBuildinTypeVoid, 0, true );
        // the string param
        PParameterDef pd = new PParameterDef( p );
        mth.mParams ~= pd;
        pd.mName = "name";
        pd.mTypeInst = new PTypeInst( gBuildinTypeCharD, 1, true );

        // Statement List
        mth.mStatList = new PStatList;

        // for each call make an if testing the parm, then call the method.
        foreach( InitCall ic; inits ){

            PStatIf sif = new PStatIf;
            mth.mStatList.mStats ~= sif;

            // the condition
            PExprBinary ebin = new PExprBinary;
            ebin.mOp = "==";

            PExprLiteral e = new PExprLiteral();
            e.mType = LiteralType.LITERAL_null;
            e.mText = "\"" ~ ic.cls.getFqn() ~ "\"";
            e.mResolvedTypeInst = new PTypeInst( gBuildinTypeChar, 1, true );

            ebin.mLExpr = e;
            ebin.mRExpr = new PExprVarRef( pd );
            ebin.mResolvedTypeInst = new PTypeInst( gBuildinTypeBoolean, 0, true );
            sif.mCond = ebin;

            // the call
            PExprMethodCall ecall = new PExprMethodCall();
            sif.mTCase = ecall;
            ecall.mResolvedCallable = ic.meth;
            ecall.mTrgExpr = new PExprTypeInst( new PTypeInst( ic.cls, 0, true ));
            ecall.mName = ic.meth.mName.dup;
            ecall.mAsStatement = true;
            ecall.mResolvedTypeInst = new PTypeInst( gBuildinTypeVoid, 0, true );
        }
    }
    override void visit( PClassDef p ){
        PClassDef bak = clazz;
        clazz = p;
        super.visit( p );
        clazz = bak;
    }
    override void visit( PMethodDef p ){
        if( p.mName == "static_this" ){
            auto i = new InitCall;
            i.meth = p;
            i.cls  = clazz;
            inits ~= i;
        }
    }

}




