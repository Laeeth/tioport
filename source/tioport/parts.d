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
module tioport.parts;

import tioport.partvisitor;
import tioport.refactorings;
import tioport.utils;

import tango.io.Stdout;
import tango.text.Util : locatePrior, replace;

const EXACT_MATCH = 1_000_000;
const MATCH_OBJ = 10;
const MATCH_CAST_OBJ = 1;
const MATCH_CAST_INTF = 2;

enum Protection {
    PUBLIC,
    PACKAGE,
    PROTECTED,
    PRIVATE,
    NOTHING, // is set to nothing
    NOTSET
}

private PRootPackage gRootPackage;

PModule              gJavaIntern;
PBuildinType         gBuildinTypePtr;
PBuildinType         gBuildinTypeVoid;
PBuildinType         gBuildinTypeUInt;
PBuildinType         gBuildinTypeBoolean;
PBuildinType         gBuildinTypeChar;
PBuildinType         gBuildinTypeCharD;
PBuildinType         gBuildinTypeByte;
PBuildinType         gBuildinTypeShort;
PBuildinType         gBuildinTypeInt;
PBuildinType         gBuildinTypeLong;
PBuildinType         gBuildinTypeFloat;
PBuildinType         gBuildinTypeDouble;
PBuildinTypeNull     gBuildinTypeNull;
PTypeDef             gTypeJavaLangString;
PTypeDef             gTypeJavaLangJArray;

class PBuildinType : PTypeDef {
    bool        mIsPtr;
    int         mOrder;
    char[]      mDefaultValue;
    LiteralType mLiteralType;
    char[]      mMangledTypeName;

    PFieldDef   mClass;

    public this(char[] aName, char[] aDefaultValue, LiteralType aLiteralType, int aOrder, char[] aMangledTypeName ){
        super( gJavaIntern );
        mName         = aName;
        mOrder        = aOrder;
        mDefaultValue = aDefaultValue;
        mLiteralType  = aLiteralType;
        mMangledTypeName = aMangledTypeName;
    }
    public override int opCmp(Object aOther){
        PBuildinType o = cast(PBuildinType)aOther;

        if (mOrder == o.mOrder) {
            return(0);
        }
        if (mOrder < o.mOrder) {
            return(-1);
        }
        return(1);
    }
    override int isCompatibleTo(PTypeDef aTypeDef, bool aIsArray){

        PBuildinType t = cast(PBuildinType)aTypeDef;
        if( t is null ){
            return 0;
        }
        if( this is aTypeDef ){
            return EXACT_MATCH;
        }
        if (t.mOrder == 0 || mOrder == 0) {
            return(0);
        }

        if( t.mOrder >= mOrder && mOrder <= 3 && t.mOrder == 3 ){
            return 10000;
        }

        if( t.mOrder >= mOrder && mOrder <= 4 && t.mOrder == 4 ){
            return 1000;
        }

        if(t.mOrder >= mOrder){
            return 100;
        }
        return(0);
    }

    override char[] getFqn( bool excludeModule = false ){
        if( mIsPtr ){
            return mName ~ "*";
        }
        else{
            return mName;
        }
    }
    public override char[] mangledType(){
        return mMangledTypeName;
    }
}

class PBuildinTypeNull : PBuildinType {
    public this(){
        super("null", "null", LiteralType.LITERAL_null, 0, "0" );
    }

    override int isCompatibleTo(PTypeDef aTypeDef, bool aIsArray){

        // null is not compatible to buildin types
        //TODO: This is only true if the buildin type is not an array, but this info is not accessible...
        PBuildinType t = cast(PBuildinType)aTypeDef;
        if( !aIsArray && t !is null ){
            return 0;
        }

        return(EXACT_MATCH);
    }
}

static this(){
    gRootPackage = new PRootPackage();
    gJavaIntern = new PModule();
    gJavaIntern.mName = "Intern";
    gBuildinTypeNull    = new PBuildinTypeNull();
    gBuildinTypePtr     = new PBuildinType("void", "", cast(LiteralType)0, 0, "V");
    gBuildinTypePtr.mIsPtr = true;
    gBuildinTypeVoid    = new PBuildinType("void", "", cast(LiteralType)0, 0, "V");
    gBuildinTypeBoolean = new PBuildinType("boolean", "false", LiteralType.LITERAL_false, 0, "Z");
    gBuildinTypeChar    = new PBuildinType("char", "' '", LiteralType.CHAR_LITERAL, 1, "C");
    gBuildinTypeByte    = new PBuildinType("byte", "0", LiteralType.NUM_INT, 1, "B");
    gBuildinTypeShort   = new PBuildinType("short", "0", LiteralType.NUM_INT, 2, "S");
    gBuildinTypeUInt    = new PBuildinType("uint", "0", LiteralType.NUM_INT, 3, "Iu");
    gBuildinTypeInt     = new PBuildinType("int", "0", LiteralType.NUM_INT, 3, "I");
    gBuildinTypeLong    = new PBuildinType("long", "0L", LiteralType.NUM_LONG, 4, "J");
    gBuildinTypeFloat   = new PBuildinType("float", "0.0f", LiteralType.NUM_FLOAT, 5, "F");
    gBuildinTypeDouble  = new PBuildinType("double", "0.0", LiteralType.NUM_DOUBLE, 6, "D");

    gBuildinTypeCharD   = new PBuildinType("char", "' '", LiteralType.CHAR_LITERAL, 1, "C");
}

public void initializeWellKnownTypes(){
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeNull;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeVoid;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeUInt;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeBoolean;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeChar;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeByte;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeShort;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeInt;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeLong;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeFloat;
    gRootPackage.mGlobalTypeDefs ~= gBuildinTypeDouble;

    gRootPackage.mJavaPackage = gRootPackage.findChildPackage("java");
    gRootPackage.mJavaLangPackage = gRootPackage.mJavaPackage.findChildPackage("lang");
    gRootPackage.mJavaPackage.mModules ~= gJavaIntern;
    gJavaIntern.mPackage = gRootPackage.mJavaPackage;

    gTypeJavaLangString = gRootPackage.mJavaLangPackage.findChildTypeDef("String");
    gTypeJavaLangJArray = gRootPackage.mJavaLangPackage.findChildTypeDef("JArray");
    assert( gTypeJavaLangJArray !is null );
}

PRootPackage getPackageRoot(){
    return(gRootPackage);
}

template PartStdImpl(bool override_=false){
    static if(override_)
    {
	    override void accept(Visitor v){
		v.visit(this);
	    }
    }
    else
    {
	    void accept(Visitor v){
		//Stdout.formatln( "{0}", toUtf8() );
		//Stdout.print(this.mangleof);
		//Stdout.newline;
		//Stdout.flush();
		v.visit(this);
	    }
    }
}

abstract class PPart {
    PPart mPartParent;
    abstract void accept(Visitor v);
    abstract void exchangeExpr(PExpr aChild, PExpr aNewExpr);
    void exchangeStat(PStatement aChild, PStatement aNewStat){
    }
}

interface IScope {
    //IScope findChildScope(char[] aName);
    //IScope findScopeWithName(char[] aName);
    //IScope findScopeWithTypeDef(char[] aName);

    PPackage      findChildPackage(char[] aName);
    //PModule       findChildModule(char[] aName);
    PTypeDef      findChildTypeDef(char[] aName);
    PTypeDef      findOuterTypeDef();
    PTypeInst     findTypeInst(char[] aName);
    PParameterDef findParameterDef(char[] aName);
    PCallable     findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance);
    char[]        toUtf8();
    //PParameterDef findParameterDef(char[] aName);
}

class PRootPackage : PPackage {
    mixin PartStdImpl!true;
    PPackage   mJavaPackage;
    PPackage   mJavaLangPackage;
    PTypeDef[] mGlobalTypeDefs;

    override PTypeDef findChildTypeDef(char[] aName){
        assert(mJavaLangPackage !is null);
        foreach (PTypeDef td; mGlobalTypeDefs) {
            if (td.mName == aName) {
                return(td);
            }
        }
        if (PTypeDef td = mJavaLangPackage.findChildTypeDef(aName)) {
            return(td);
        }
        return(super.findChildTypeDef(aName));
    }
}

class PPackage : PPart, IScope {
    mixin PartStdImpl!(true);
    PPackage[] mPackages;
    PModule[]  mModules;
    char[]     mName;
    PPackage   mParent;

    PPackage[] getPackages(){
        return(mPackages);
    }
    PModule[] getModules(){
        return(mModules);
    }


    PPackage getOrCreatePackage(char[] aName){
        PPackage p = findChildPackage(aName);

        if (!p) {
            p         = new PPackage;
            p.mName   = aName;
            p.mParent = this;
            mPackages ~= p;
        }
        return(p);
    }

    PModule createFqnModule(char[] aName){
        //FIXME no fqn procession
        return createModule( aName );
    }

    PModule createModule(char[] aName){
        assert(findChildModule(aName) is null, aName );
        PModule p = new PModule;
        p.mName    = aName;
        p.mPackage = this;
        mModules ~= p;
        return(p);
    }

    char[] getFqn(){
        if (mParent is null) {
            return(null);
        }
        char[] res = mParent.getFqn();
        if (res is null) {
            return(mName);
        }
        else {
            return(res ~ '.' ~ mName);
        }
    }
    PModule  findChildModule(char[] aName){
        foreach (PModule p; mModules) {
            if (p.mName == aName) {
                return(p);
            }
        }
        return(null);
    }

    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        assert(false);
    }
    ///////////////////////////////////////////
    // IScope
    PPackage findChildPackage(char[] aName){
        foreach (PPackage p; mPackages) {
            if (p.mName == aName) {
                return(p);
            }
        }
        return(null);
    }
    PTypeDef findChildTypeDef(char[] aName){
        if (PModule mod = findChildModule(aName)) {
            return(mod.findChildTypeDef(aName));
        }
        return(null);
    }
    PTypeDef findOuterTypeDef(){
        return(null);
    }
    PTypeInst findTypeInst(char[] aName){
        return(null);
    }
    PParameterDef findParameterDef(char[] aName){
        return(null);
    }
    PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
        return(null);
    }
    char[] toUtf8(){
        return(Layouter("[PPackage mName={0}]", mName));
    }
}

class PModule : PPart, IScope {
    mixin PartStdImpl!true;
    char[]       mHeaderText;
    PPackage     mPackage;
    PImport[]    mImports;
    PTypeDef[]   mTypeDefs;
    PTypeDef[]   mVsibileTypeDefs; // these are visible for resolving types.
    PModule[]    mImportedModules; // these are really imported
    PMethodDef[] mModuleMethods;
    char[]       mName;
    bool         mIsStub; // stubs are not written to D targets.
    bool         mIsNowrite; // Do not write any output file for this module.

    char[][ char[] ] mExchangeFuncs;

    public this(){
        mPackage = new PPackage;
    }
    char[]       getFqn(){
        if( mPackage is null ){
            return mName;
        }
        char[] res = mPackage.getFqn();
        if (res is null) {
            return(mName);
        }
        else {
            return(res ~ '.' ~ mName);
        }
    }

    PTypeDef findImportedTypeDef(char[] aName){
        foreach (PTypeDef p; mVsibileTypeDefs) {
            if (p.mName == aName) {
                return(p);
            }
        }
        return(null);
    }

    PMethodDef createMethod( char[] aName ){
        PMethodDef res = new PMethodDef;
        res.mName = aName;
        res.mModifiers = new PModifiers;
        mModuleMethods ~= res;
        return res;
    }

    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        assert(false);
    }

    ///////////////////////////////////////////
    // IScope
    PPackage findChildPackage(char[] aName){
        return(null);
    }
    PTypeDef findChildTypeDef(char[] aName){
        foreach (PTypeDef p; mTypeDefs) {
            if (p.mName == aName) {
                return(p);
            }
        }
        return(null);
    }
    PTypeDef findOuterTypeDef(){
        return(null);
    }
    PTypeInst findTypeInst(char[] aName){
        return(null);
    }
    PParameterDef findParameterDef(char[] aName){
        return(null);
    }
    PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
        return(null);
    }
    char[] toUtf8(){
        return(Layouter("[PModule mName={0}]", mName));
    }
}
class PUnnamedModule : PModule {
    override char[]       getFqn(){
        return "";
    }
}

class PImport : PPart {
    mixin PartStdImpl!true;
    char[][] mTexts;
    PModule  mModule;
    bool     mStatic;
    bool     mStar;

    public this(char[][] aTexts, bool aStar, bool aStatic){
        mTexts  = aTexts.dup;
        mStar   = aStar;
        mStatic = aStatic;
    }

    char[]   getFqn(){
        char[] res;
        foreach (char[] t; mTexts) {
            res = (res is null) ? t : (res ~ '.' ~ t);
        }
        return(res);
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        assert(false);
    }
    char[] toUtf8(){
        return(Layouter("[PImport fqn={0}]", getFqn()));
    }
}

class PModifiers {
    public static char[] mExternIdent = "C".dup;
    Protection mProtection = Protection.NOTSET;
    bool       mTransient;
    bool       mFinal;
    bool       mAbstract;
    bool       mNative;
    bool       mThreadsafe;
    bool       mSynchronized;
    bool       mConst;
    bool       mStatic;
    bool       mVolatile;
    bool       mStrictfp;

    PModifiers clone(){
        PModifiers result = new PModifiers;

        result.mProtection   = mProtection;
        result.mTransient    = mTransient;
        result.mFinal        = mFinal;
        result.mAbstract     = mAbstract;
        result.mNative       = mNative;
        result.mThreadsafe   = mThreadsafe;
        result.mSynchronized = mSynchronized;
        result.mConst        = mConst;
        result.mStatic       = mStatic;
        result.mVolatile     = mVolatile;
        result.mStrictfp     = mStrictfp;
        return(result);
    }
    char[]     getString(){
        char[] res;
        switch (mProtection) {
        case Protection.PUBLIC:
            res ~= "public "; break;

        case Protection.PROTECTED:
            res ~= "protected package "; break;

        case Protection.PACKAGE:
            res ~= "package "; break;

        case Protection.PRIVATE:
            res ~= "private "; break;

        default:
            break;
        }
        if (mFinal) {
            res ~= "final ";
        }
        if (mAbstract) {
            res ~= "abstract ";
        }
        if (mNative) {
            res ~= "extern( " ~ mExternIdent ~ ") ";
        }
        if (mSynchronized) {
            res ~= "synchronized ";
        }
        if (mConst) {
            res ~= "const ";
        }
        if (mStatic) {
            res ~= "static ";
        }
        if (mVolatile) {
            res ~= "volatile ";
        }
        return(res);
    }
    bool isStatic(){
        return(mStatic);
    }
    char[] toUtf8(){
        return(Layouter("[PModifier str={0}]", getString()));
    }
    const uint BIT_FINAL        = 0x04;
    const uint BIT_ABSTRACT     = 0x08;
    const uint BIT_NATIVE       = 0x10;
    const uint BIT_SYNCHRONIZED = 0x20;
    const uint BIT_CONST        = 0x40;
    const uint BIT_STATIC       = 0x80;

    int asInt(){
        int res = 0;
        switch (mProtection) {
        case Protection.PUBLIC:    res = 0; break;
        case Protection.PROTECTED: res = 1; break;
        case Protection.PACKAGE:   res = 2; break;
        case Protection.PRIVATE:   res = 3; break;
        default: break;
        }
        if (mFinal) {
            res |= 0x04;
        }
        if (mAbstract) {
            res |= 0x08;
        }
        if (mNative) {
            res |= 0x10;
        }
        if (mSynchronized) {
            res |= 0x20;
        }
        if (mConst) {
            res |= 0x40;
        }
        if (mStatic) {
            res |= 0x80;
        }
        if (mVolatile) {
            res |= 0x100;
        }
        return(res);
    }
}

class PTypeRef {
    PTypeRefPart[] mParts;
    PTypeDef       mResolvedTypeDef;

    PTypeInst[]    mTypeArgs;

    PTypeInst[]    mGenericArgs;

    PTypeRef clone(){
        PTypeRef result = new PTypeRef;

        foreach (PTypeRefPart part; mParts) {
            result.mParts ~= part.clone();
        }
        result.mResolvedTypeDef = mResolvedTypeDef;
        result.mGenericArgs = mGenericArgs.dup;
        return(result);
    }

    public override bool opEquals( Object o ){
        PTypeRef t = cast(PTypeRef) o;
        if( t is null ){
            return false;
        }
        //if( mParts != t.mParts ){
        //    return false;
        //}
        if( mResolvedTypeDef !is t.mResolvedTypeDef ){
            return false;
        }
        //if( mTypeArgs != t.mTypeArgs ){
        //    return false;
        //}
        return true;
    }

    char[] getTypeArgsString(){
        char[] res;
        if (mTypeArgs !is null) {
            res ~= "!(";
            bool first = true;
            foreach (PTypeInst ti; mTypeArgs) {
                res ~= first ? " " : ", ";
                res ~= ti.getString();
                first = false;
            }
            res ~= ")";
        }
        return res;
    }
    char[]         getString(){
        if (mResolvedTypeDef !is null) {
            return(mResolvedTypeDef.getString( getTypeArgsString()));
        }
        else {
            char[] res;
            foreach (PTypeRefPart tp; mParts) {
                res = res is null ? tp.mText : res ~ '.' ~ tp.mText;
            }
            return(res ~ getTypeArgsString());
        }
    }

    char[] toUtf8(){
        char[] res = getString();
        if( mGenericArgs.length > 0 ){
            res ~= "<";
            bool first = true;
            foreach( PTypeInst ti; mGenericArgs ){
                if( !first ){
                    res ~= ", ";
                }
                res ~= ti.toUtf8;
                first = false;
            }
            res ~= ">";
        }
        return( res );
    }

    char[] mangledType(){
        return mResolvedTypeDef.mangledType();
    }
}

class PTypeRefPart {
    char[] mText;
    // can also hold <typearguments>
    public this(){ }
    public this(char[] aText){ mText = aText; }
    PTypeRefPart clone(){
        PTypeRefPart result = new PTypeRefPart;

        result.mText = mText.dup;
        return(result);
    }
}

class PTypeInst {
    PTypeRef mTypeRef;
    int      mDimensions;
    bool     mIsInstance = true;

    this(){
        mTypeRef = new PTypeRef;
    }

    PTypeInst clone(){
        PTypeInst result = new PTypeInst;

        result.mTypeRef    = (mTypeRef is null) ? null : mTypeRef.clone();
        result.mDimensions = mDimensions;
        result.mIsInstance = mIsInstance;
        return(result);
    }

    this(PTypeDef aResolvedTypeDef, int aDimensions, bool aIsInstance){
        mTypeRef                  = new PTypeRef;
        mTypeRef.mResolvedTypeDef = aResolvedTypeDef;
        mDimensions               = aDimensions;
        assert( mDimensions >= 0 );
        mIsInstance               = aIsInstance;
    }

    bool isSameType( PTypeInst t ){
        if( mDimensions != t.mDimensions ){
            return false;
        }
        if( mIsInstance != t.mIsInstance ){
            return false;
        }
        return cast(bool)(mTypeRef == t.mTypeRef);
    }

    char[]   getString(){
        char[] res;
        res = mTypeRef.getString();
        for (int i = 0; i < mDimensions; i++) {
            res ~= "[]";
        }
        return(res ~ " ");
    }
    char[] toUtf8(){
        char[] res;
        res = mTypeRef.toUtf8();
        for (int i = 0; i < mDimensions; i++) {
            res ~= "[]";
        }
        return(res ~ " ");
    }

    // called for the calling argument
    int isCompatibleTo( PTypeInst aDef, bool aIsArray ){
        PTypeDef  defType = aDef.mTypeRef.mResolvedTypeDef;
        assert(defType !is null);
        PTypeDef  callType = mTypeRef.mResolvedTypeDef;
        assert(callType !is null);

        if(  defType is gJObjectImpl || defType is gIJObject ) {
            // always compatible, can be casted
            return MATCH_OBJ;
        }
        if (callType !is gBuildinTypeNull) {
            if (mDimensions != aDef.mDimensions ){
                //Stdout.formatln("  no match dims {0} {1}", defArg.mDimensions, callArg.mDimensions);
                return(0);
            }
        }
        return callType.isCompatibleTo(defType, aIsArray);
    }

    public override bool opEquals( Object o ){
        PTypeInst t = cast(PTypeInst) o;
        if( t is null ){
            return false;
        }
        return isSameType( t );
    }
}

class PTypeDef : PStatement, IScope {
    mixin PartStdImpl!(true);
    char[]     mName;
    PPackage   mPackage;
    PModule    mModule;
    PTypeDef   mParent;
    PModifiers mModifiers;

    this( PModule aModule ){
        mModule = aModule;
    }

    public override bool opEquals( Object o ){
        PTypeDef t = cast(PTypeDef) o;
        if( t is null ){
            return false;
        }
        if( mName != t.mName ){
            return false;
        }
        if( mPackage != t.mPackage ){
            return false;
        }
        if( mModule != t.mModule ){
            return false;
        }
        if( mParent != t.mParent ){
            return false;
        }
        return true;
    }
    //PTypeDef clone(){
    //    PTypeDef result = new PTypeDef;
    //    result.mName = mName.dup;
    //    result.mPackage = mPackage;
    //    result.mModule  = mModule;
    //    result.mParent = mParent;
    //    result.mModifiers = mModifiers.clone();
    //    return result;
    //}
    char[]     getFqn( bool excludeModule = false ){
        char[]   res;
        PTypeDef cur = this;
        PModule  mod;
        while (cur !is null) {
            res = res is null ? cur.mName : cur.mName ~ "." ~ res;
            mod = cur.mModule;
            cur = cur.mParent;
        }
        if (mod is null ) {
            return(mName); // buildin types
        }
        else {
            char[] modfqn = mod.getFqn();
            if( excludeModule ){
                int idx = .locatePrior( modfqn, '.' );
                modfqn = modfqn[ 0 .. idx ];
            }
            if( modfqn ){
                return(modfqn ~ "." ~ res);
            }
            else{
                return mName;
            }
        }
    }
    char[] getString( char[] aTypeArgs ){
        return getFqn() ~ aTypeArgs;
    }

    int isCompatibleTo(PTypeDef aTypeDef, bool aIsArray){
        if (aTypeDef is gBuildinTypeNull) {
            return(EXACT_MATCH);
        }
        if(this is aTypeDef){
            return(EXACT_MATCH);
        }
        return 0;
    }

    ///////////////////////////////////////////
    // IScope
    override PPackage findChildPackage(char[] aName){
        return(null);
    }
    override PTypeDef findChildTypeDef(char[] aName){
        //Stdout.formatln("PTypedef findchilddtype {0}", mName, aName);
        return(null);
    }
    override PTypeDef findOuterTypeDef(){
        return(mParent);
    }
    override PTypeInst findTypeInst(char[] aName){
        return(null);
    }
    override PParameterDef findParameterDef(char[] aName){
        return(null);
    }
    override PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
        return(null);
    }
    override char[] toUtf8(){
        return(Layouter("[PTypeDef mName={0}]", mName));
    }
    char[] mangledType(){
        return "L" ~ .replace( getFqn( true ), '.', '/' ) ~ ";";
    }
}

class PFuncTypeDef : PTypeDef {
    bool       mIsDelegate;
    //PMethodDef mMethodDef;
    PTypeInst   mReturnType;
    PParameterDef[] mParams;

    this( PModule aModule ){
        super( aModule );
    }

    char[]     getFqn(){
        char[]   res = mReturnType.getString();
        res ~= " ";
        res ~= mIsDelegate ? "delegate" : "function";
        res ~= "(";
        foreach( uint parIdx, PParameterDef pd; mParams ){
            if( parIdx > 0 ){
                res ~= " ";
            }
            res ~= pd.getString();
        }
        res ~= ")";
        return(res);
    }

    override char[] getString( char[] aTypeArgs ){
        char[]   res = mReturnType.getString();
        res ~= " ";
        res ~= mIsDelegate ? "delegate" : "function";
        res ~= "(";
        foreach( uint parIdx, PParameterDef pd; mParams ){
            if( parIdx > 0 ){
                res ~= ", ";
            }
            res ~= pd.mTypeInst.getString();
        }
        res ~= ")";
        return(res);
    }
}

class PTypeParameter{
    char[]      mName;
    PTypeRef[]  mUpperBounds;
}

class PInterfaceDef : PTypeDef {
    mixin PartStdImpl!true;
    PTypeRef[]        mSuperIfaces;
    PMethodDef[]      mMethods;
    PTypeDef[]        mTypeDefs;

    PTypeParameter    mTypeParams;

    // hash char[] -> PMethodDef[]
    // the PCtor[] contains a list of all methods/ctors with this name,
    // but they have unique signatures. (overridden ones are removed)
    // ctors are stored with name 'this'.
    PCtor[][ char[] ] mAccessibleMethods;

    public this( PModule aModule ){
        super( aModule );
    }

    PMethodDef findMethod( char[] aName ){
        PMethodDef res = null;
        foreach( PMethodDef mth; mMethods ){
            if( mth.mName == aName ){
                res = mth;
            }
        }
        assert( res !is null, toUtf8 );
        return res;
    }
    override PTypeDef findChildTypeDef(char[] aName){
        foreach (PTypeDef p; mTypeDefs) {
            //Stdout.formatln("Pinterface findchilddtype{0} {1}", p.mName, aName);
            if (p.mName == aName) {
                return(p);
            }
        }
        return(super.findChildTypeDef(aName));
    }

    bool isCompatibleTo(PTypeDef aTypeDef, bool aIsArray){
        if (aTypeDef is gBuildinTypeNull) {
            return( EXACT_MATCH );
        }

        if ((cast(PBuildinType)aTypeDef) !is null) {
            return(0); // not compatible to buildin types
        }

        if (this is aTypeDef) {
            return( EXACT_MATCH );
        }

        if (aTypeDef is gJObjectImpl) {
            return( MATCH_OBJ );
        }

        int bestMatch = 0;
        foreach (PTypeRef tr; mSuperIfaces) {
            int value = tr.mResolvedTypeDef.isCompatibleTo(aTypeDef, aIsArray ) - MATCH_CAST_INTF;
            if( value > bestMatch ){
                bestMatch = value;
            }
        }
        return bestMatch;
    }

    // 0 == exact
    // 1 == byte, short, char -> int, float -> double
    // 2 == byte, short, char, int -> long
    const int MAX_RESOLVE_LEVEL = 3;
    override PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
        static int callCnt = 0;
        callCnt++;
        PCtor[] bestMatches;
        int     bestMatchIdx;
        char[] logName = "1";

        if( aName == logName ) Stdout.formatln( "---- {0}", callCnt );

        assert( aName in mAccessibleMethods, Layouter("iface {0} searched method {1}", toUtf8(), aName));
        // make preselection of available methods
        PCtor[] availableCTors = mAccessibleMethods[ aName ];
        assert(availableCTors.length !is 0, Layouter("iface {0} searched method {1}", toUtf8(), aName));


        // sort out methods that are not compatible
        PCtor[] areCallable;
ctor_loop:
        foreach( PCtor ct; availableCTors ){

            if( aName == logName ) Stdout.formatln( "Line {0} test for: {1}", __LINE__, ct.toUtf8 );

            bool varLength = false;
            if( ct.mParams.length > 0 ){
                varLength = ct.mParams[$-1].mIsVariableLength;
            }

            if( !varLength && aArgTypes.length < ct.mParams.length  ){
                if( aName == logName ) Stdout.formatln( "Line {0} ", __LINE__ );
                continue;
            }

            if( varLength && aArgTypes.length < ct.mParams.length-1 ){
                if( aName == logName ) Stdout.formatln( "Line {0} ", __LINE__ );
                continue;
            }

            if( ! varLength ){
                for( int i = 0; i < ct.mParams.length; i++ ){
                    PParameterDef pd = ct.mParams[i];
                    if( aArgTypes[i].isCompatibleTo( pd.mTypeInst, pd.mTypeInst.mDimensions > 0 ) == 0 ){
                        if( aName == logName ) Stdout.formatln( "Line {0} ", __LINE__ );
                        continue ctor_loop;
                    }
                }
            }
            else{
                for( int i = 0; i < ct.mParams.length-1; i++ ){
                    PParameterDef pd = ct.mParams[i];
                    if( aArgTypes[i].isCompatibleTo( pd.mTypeInst, pd.mTypeInst.mDimensions > 0 ) == 0 ){
                        if( aName == logName ) Stdout.formatln( "Line {0} ", __LINE__ );
                        continue ctor_loop;
                    }
                }
                PTypeInst[] remainArgs = aArgTypes[ ct.mParams.length -1 .. $ ];
                if( remainArgs.length == 1 && remainArgs[0].mDimensions == 1 ){
                    PTypeInst ti = ct.mParams[$-1].mTypeInst.clone();
                    ti.mDimensions++;
                    if( remainArgs[0].isCompatibleTo( ti, true ) == 0 ){
                        if( aName == logName ) Stdout.formatln( "Line {0} arg:{1} param:{2}", __LINE__, remainArgs[0].toUtf8, ti.toUtf8 );
                        continue ctor_loop;
                    }
                }
                else{
                    foreach( PTypeInst pi; remainArgs ){
                        if( pi.isCompatibleTo( ct.mParams[$-1].mTypeInst, ct.mParams[$-1].mTypeInst.mDimensions > 0 ) == 0 ){
                            if( aName == logName ) Stdout.formatln( "Line {0} ", __LINE__ );
                            continue ctor_loop;
                        }
                    }
                }
            }
            areCallable ~= ct;
        }

        if( areCallable.length == 1 ){
            return areCallable[0];
        }
        if( areCallable.length == 0 ){
            if( aName == logName ) Stdout.formatln( "Line {0} ", __LINE__ );
            goto print;
        }

        foreach( PCtor ct; areCallable ){

            int rating;
            for( int i = 0; i < ct.mParams.length; i++ ){
                PParameterDef pd = ct.mParams[i];
                rating += aArgTypes[i].isCompatibleTo( pd.mTypeInst, pd.mTypeInst.mDimensions > 0 );
                if( pd.mIsVariableLength ){
                    rating -= 3;
                }
                rating -= pd.mTypeInst.mDimensions;
            }
            if( rating > bestMatchIdx ){
                bestMatchIdx = rating;
                bestMatches = [ ct ];
            }
            else if( bestMatchIdx > 0 && rating == bestMatchIdx ){
                bestMatches ~= ct;
            }
        }

        if( bestMatches.length == 1 ){
            return bestMatches[0];
        }
print:
        foreach( PCtor ct; availableCTors ){
            Stdout.formatln( " available {0}", ct );
        }
        foreach( PCtor ct; areCallable ){
            Stdout.formatln( " callable {0}", ct );
        }
        foreach( PCtor ct; bestMatches ){
            Stdout.formatln( " best {0}", ct );
        }
        foreach( PTypeInst ti; aArgTypes ){
            Stdout.formatln( " arg {0}", ti.toUtf8 );
        }
        Stdout.formatln( " callCnt {0}", callCnt );
        assert( false, Layouter("iface {0} searched method {1}", toUtf8(), aName));
        return null;

        ////Stdout.formatln("  iface {0} searching method {1}", toUtf8(), aName);

        //PCallable res = null;

        //for( int i = 0; i < MAX_RESOLVE_LEVEL; i++ ){
        //    res = findCallableRecurse(aName, aArgTypes, aIsInstance, i);
        //    if (res !is null) {
        //        return(res);
        //    }
        //}
        //assert(res !is null, Layouter("iface {0} searched method {1}", toUtf8(), aName));
        //return(res);

        //// print diagnose stuff
        //ocls = this;
        //int depth = 0;
        //while( ocls !is null ){
        //    cls = ocls;
        //    while( cls !is null ){
        //        Stdout.formatln( "  {0}. class {1} ", depth, cls.getFqn() );
        //        foreach( PMethodDef m; cls.mMethods ){
        //            Stdout.formatln( "{0}", m.toUtf8() );
        //        }
        //        if( cls.mSuperClass is null ){
        //            break;
        //        }
        //        cls = cast(PClassDef)cls.mSuperClass.mResolvedTypeDef;
        //        depth ++;
        //        cls = ( cls.mSuperClass is null ) ? null : cast(PClassDef) cls.mSuperClass.mResolvedTypeDef;
        //    }
        //    ocls = cast(PClassDef)ocls.findOuterTypeDef();
        //}
        //assert( false, Layouter( "class {0} searched method {1}", toUtf8(), aName ) );
        //return(null);
    }
    override char[]            toUtf8(){
        return(Layouter("[PInterfaceDef mName={0}]", mName));
    }
}
class AliasFunction{
    PClassDef mClassDef;
    char[]    mName;
}
class PClassDef : PInterfaceDef {
    mixin PartStdImpl!true;
    PTypeRef          mSuperClass;
    PFieldDef[]       mFields;
    PCtor[]           mCtors;
    PStaticCtor[]     mStaticCtors;
    PInstanceInit[]   mInstanceInits;
    PPart[]           mOriginalDeclOrder;

    PFieldDef         mThis;
    PFieldDef         mClass;
    PFieldDef         mOuter;
    AliasFunction[]   mAliases;

    public this( PModule aModule ){
        super( aModule );
        // every class has a this ptr
        mThis                                     = new PFieldDef( aModule );
        mThis.mName                               = "this";
        mThis.mModifiers                          = new PModifiers;
        mThis.mTypeInst                           = new PTypeInst;
        mThis.mTypeInst.mTypeRef                  = new PTypeRef;
        mThis.mTypeInst.mTypeRef.mResolvedTypeDef = this;

        // resolve in BaseFixer
        //mClass.mTypeInst.mTypeRef.mResolvedTypeDef = ??;
    }

    override PTypeInst findTypeInst(char[] aName){
        foreach (PFieldDef v; mFields) {
            //Stdout.formatln( "{0} : compare fieldname {1} == {2}", toUtf8(), v.mName, aName );
            if (v.mName == aName) {
                assert(v.mTypeInst !is null);
                assert(v.mTypeInst.mTypeRef.mResolvedTypeDef !is null);
                return(v.mTypeInst);
            }
        }
        if (mSuperClass !is null && mSuperClass.mResolvedTypeDef !is null) {
            PTypeInst ti = mSuperClass.mResolvedTypeDef.findTypeInst(aName);
            if (ti !is null) {
                return(ti);
            }
        }
        return(null);
    }

    override PParameterDef findParameterDef(char[] aName){
        foreach (PFieldDef v; mFields) {
            //Stdout.formatln( "{0} : compare fieldname {1} == {2}", toUtf8(), v.mName, aName );
            if (v.mName == aName) {
                assert(v.mTypeInst !is null);
                assert(v.mTypeInst.mTypeRef.mResolvedTypeDef !is null);
                return(v);
            }
        }
        if (mSuperClass !is null && mSuperClass.mResolvedTypeDef !is null) {
            PParameterDef ti = mSuperClass.mResolvedTypeDef.findParameterDef(aName);
            if (ti !is null) {
                return(ti);
            }
        }
        return(null);
    }

    PMethodDef createMethod( char[] aName ){
        PMethodDef res = new PMethodDef;
        res.mName = aName;
        res.mModifiers = new PModifiers;
        mMethods ~= res;
        return res;
    }

    override bool isCompatibleTo(PTypeDef aTypeDef, bool aIsArray){
        if (aTypeDef is gBuildinTypeNull) {
            return( EXACT_MATCH);
        }
        if ((cast(PBuildinType)aTypeDef) !is null) {
            return(0); // not compatible to buildin types
        }

        PClassDef cd = cast(PClassDef) aTypeDef;
        if (this is aTypeDef) {
            return(EXACT_MATCH);
        }

        if (aTypeDef is gJObjectImpl) {
            return(MATCH_OBJ);
        }

        int bestMatch = 0;
        foreach (PTypeRef tr; mSuperIfaces) {
            int value = tr.mResolvedTypeDef.isCompatibleTo(aTypeDef, aIsArray) - MATCH_CAST_INTF;
            if( value > bestMatch ){
                bestMatch = value;
            }
        }
        if (mSuperClass !is null) {
            int value = mSuperClass.mResolvedTypeDef.isCompatibleTo(aTypeDef, aIsArray) - MATCH_CAST_OBJ;
            if( value > bestMatch ){
                bestMatch = value;
            }
        }
        return(bestMatch);
    }

    //PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
    //    PCallable res = null;

    //    for( int i = 0; i < MAX_RESOLVE_LEVEL; i++ ){
    //        res = findCallableRecurse(aName, aArgTypes, aIsInstance, i);
    //        if (res !is null) {
    //            return(res);
    //        }
    //    }

    //    Stdout.format("class {0} searched method ", toUtf8());
    //    Stdout.format(" {0}( ", aName);

    //    foreach ( uint tiIdx, PTypeInst ti; aArgTypes) {
    //        Stdout.print( !tiIdx ? "" : ", ");
    //        Stdout.format("{0}", ti.mTypeRef.toUtf8());
    //        for (int i = 0; i < ti.mDimensions; i++) {
    //            Stdout.print("[]");
    //        }
    //    }
    //    Stdout.print(" )");
    //    Stdout.newline;
    //    assert(false);
    //    return(res);
    //}
    override char[]            toUtf8(){
        return(Layouter("[PClassDef fqn={0}]", getFqn()));
    }
}

class PObjectClassDef : PClassDef {
    public this( PModule m ){
        super(m);
    }
    public override char[] getFqn( bool excludeModule = false ){
        return "Object";
    }
}

class PCallable : PStatement {
    mixin PartStdImpl!true;
    PModifiers mModifiers;
    PStatList  mStatList;
    char[]     mName;

    public this(){
        mModifiers = new PModifiers;
    }
}
class PStaticCtor : PCallable {
    mixin PartStdImpl!true;
}
class PInstanceInit : PCallable {
    mixin PartStdImpl!true;
}
class PCtor : PCallable {
    mixin PartStdImpl!true;
    PParameterDef[] mParams;

    public this(){
        mName = "this";
    }

    public bool hasEqualSignature( PCtor a ){
        if( mName != a.mName ){
            return false;
        }
        if( mParams.length != a.mParams.length ){
            return false;
        }
        for( int i = 0; i < mParams.length; i++ ){
            PParameterDef pa = mParams[i];
            PParameterDef pb = a.mParams[i];
            if( ! pa.isSameType( pb ) ){
                return false;
            }
        }
        return true;
    }

    override PTypeInst findTypeInst(char[] aName){
        foreach (PParameterDef v; mParams) {
            if (v.mName == aName) {
                return(v.mTypeInst);
            }
        }
        if (mStatList !is null) {
            return(mStatList.findTypeInst(aName));
        }
        return(null);
    }
    override PParameterDef findParameterDef(char[] aName){
        foreach (PParameterDef v; mParams) {
            if (v.mName == aName) {
                return(v);
            }
        }
        if (mStatList !is null) {
            return(mStatList.findParameterDef(aName));
        }
        return(null);
    }
    override PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
        return(null);
    }

    override char[]          toUtf8(){
        char[] res = "PCtor ( ";
        foreach ( uint tiIdx, PParameterDef pd; mParams) {
            Stdout.print( !tiIdx ? "" : ", ");
            res ~= pd.mTypeInst.toUtf8();
        }
        res ~= ")";
        return(res);
    }
}
class PMethodDef : PCtor {
    mixin PartStdImpl!true;
    PTypeInst mReturnType;
    PModule mModuleFunc = null;
    bool mIsNestedFunc = false;
    char[][] mComments;

    public this(){
        mName = "<unknow>";
    }

    PMethodDef cloneMethodDefDeclaration(){
        PMethodDef result = new PMethodDef;

        result.mName       = mName.dup;
        result.mReturnType = mReturnType.clone();
        result.mModifiers  = mModifiers.clone();
        foreach (PParameterDef paramDef; mParams) {
            result.mParams ~= paramDef.clone();
        }
        return(result);
    }

    override PTypeInst findTypeInst(char[] aName){
        foreach (PParameterDef v; mParams) {
            if (v.mName == aName) {
                return(v.mTypeInst);
            }
        }
        if (mStatList !is null) {
            return(mStatList.findTypeInst(aName));
        }
        return(null);
    }
    override PParameterDef findParameterDef(char[] aName){
        foreach (PParameterDef v; mParams) {
            if (v.mName == aName) {
                return(v);
            }
        }
        if (mStatList !is null) {
            return(mStatList.findParameterDef(aName));
        }
        return(null);
    }

    public override hash_t toHash(){
        hash_t hash;
        foreach (char c; toUtf8())
            hash = hash * 9 + c;
        return hash;
    }

    override char[]    toUtf8(){
        char[] res;
        res = Layouter("[PMethodDef {0}{1} {2}(", mModifiers.getString(), mReturnType.getString(), mName);
        bool   first = true;
        foreach (PParameterDef pd; mParams) {
            res ~= first ? " " : ", ";
            res ~= pd.getString();
            first = false;
        }
        res ~= " )]";
        return(res);
    }

}

class PParameterDef : PStatement {
    mixin PartStdImpl!true;
    PModifiers      mModifiers;
    PTypeInst       mTypeInst;
    char[]          mName;
    PModule         mModule;
    bool            mIsVariableLength;

    this( PModule aModule ){
        mModule = aModule;
        mModifiers = new PModifiers;
    }

    this( PModule aModule, char[] aName, PTypeInst aTi ){
        mModule = aModule;
        mModifiers = new PModifiers;
        mName = aName;
        mTypeInst = aTi;
    }

    PParameterDef clone(){
        PParameterDef result = new PParameterDef( mModule );

        result.mName      = mName.dup;
        result.mTypeInst  = mTypeInst.clone();
        result.mModifiers = mModifiers.clone();
        return(result);
    }
    char[]          getString(){
        char[] varLengthStr = mIsVariableLength ? "..." : "";
        return(Layouter("{0}{1}{2} {3}", mModifiers.getString(), mTypeInst.getString(), varLengthStr, mName));
    }
    override char[]          toUtf8(){
        return(Layouter("[PParameterDef {0}]", mName));
    }
    bool isSameType( PParameterDef other ){
        if( !mTypeInst.isSameType( other.mTypeInst ) ){
            return false;
        }
        if( mIsVariableLength != other.mIsVariableLength ){
            return false;
        }
        return true;
    }
    //public override int opEquals( Object o ){
    //    PParameterDef t = cast(PParameterDef)o;
    //    if( t is null ){
    //        return false;
    //    }
    //    //if( mName != t.mName ){
    //    //    return false;
    //    //}
    //    if( mModule != t.mModule ){
    //        return false;
    //    }
    //    if( mIsVariableLength != t.mIsVariableLength ){
    //        return false;
    //    }
    //    //if( mTypeInst != t.mTypeInst ){
    //    //    return false;
    //    //}
    //    return true;
    //}
}
class PVarDef : PParameterDef {
    mixin PartStdImpl!true;

    this( PModule aModule ){
        super( aModule );
    }

    PVarInitializer mInitializer;
    bool            mInExpression;
}
class PFieldDef : PVarDef {
    mixin PartStdImpl!true;
    this( PModule aModule ){
        super( aModule );
    }

}
class PLocalVarDef : PVarDef {
    mixin PartStdImpl!true;
    this( PModule aModule ){
        super( aModule );
    }

}

class PExpr : PStatement {
    mixin PartStdImpl!true;
    bool      mAsStatement;
    PTypeInst mResolvedTypeInst;
    override char[]    toUtf8(){
        return("PExpr");
    }
}

class PExprVarRef : PExpr {
    mixin PartStdImpl!true;
    bool mIsSuperRef;
    PParameterDef mParameterDef;
    PTypeDef mFromTypeDef;
    PExpr    mExprReference;
    bool mGetAddress;
    bool mOffsetOf;
    this(){}
    this( PParameterDef aParameterDef){
        mParameterDef = aParameterDef;
        mResolvedTypeInst = aParameterDef.mTypeInst;
    }
    override char[]        toUtf8(){
        return( Layouter( "[PExprVarRef ref:{0}", mParameterDef.toUtf8() ));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mExprReference is aChild) {
            mExprReference = aNewExpr;
            return;
        }
        assert(false);
    }
}

class PExprFncRef : PExpr {
    mixin PartStdImpl!true;
    bool mIsSuperRef;
    PMethodDef mMethodDef;
    bool mNoFqn = false;
    this(){}
    this( PMethodDef aMethodDef){
        mMethodDef = aMethodDef;
    }
    override char[]        toUtf8(){
        return( Layouter( "[PExprFncRef ref:{0}", mMethodDef.toUtf8() ));
    }
}

class PExprTypeInst : PExpr {
    mixin PartStdImpl!true;

    PExpr[]   mTypeArguments;
    public this(){
    }
    public this( PTypeInst ti ){
        mResolvedTypeInst = ti;
    }

    override char[] toUtf8(){
        return("PExprTypeInst " ~ mResolvedTypeInst.toUtf8());
    }
}

class PExprIdent : PExpr {
    mixin PartStdImpl!true;
    char[]        mName;
    bool          mAllowNonResolve; // for the case, this is a part of fqn, so it is not a type and can be not resolved.
    PParameterDef mParameterDef;

    override char[]        toUtf8(){
        return("PExprIdent " ~ mName);
    }
}
class PExprDot : PExpr {
    mixin PartStdImpl!true;
    PExpr mLExpr;
    PExpr mRExpr;

    // if this part of a fqn is a package reference
    PPackage mResolvedPackage;

    override char[]   toUtf8(){
        return("PExprDot: " ~ mLExpr.toUtf8 ~ "/" ~ mRExpr.toUtf8);
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mLExpr is aChild) {
            mLExpr = aNewExpr;
            return;
        }
        if (mRExpr is aChild) {
            mRExpr = aNewExpr;
            return;
        }
        assert(false);
    }
}
class PExprMethodCall : PExpr {
    mixin PartStdImpl!true;
    char[]    mName;
    PExpr     mTrgExpr;
    PExpr[]   mTypeArguments;
    PExpr[]   mArguments;
    PCallable mResolvedCallable;

    override char[]    toUtf8(){
        char[] name = mName is null ? mResolvedCallable.mName : mName;
        return( Layouter( "[PExprMethodCall: {0}]", name));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mTrgExpr is aChild) {
            mTrgExpr = aNewExpr;
            return;
        }
        foreach (inout PExpr arg; mArguments) {
            if (arg is aChild) {
                arg = aNewExpr;
                return;
            }
        }
        assert(false, toUtf8());
    }

    //public void resolveMethod(){
    //    PTypeInst[] tis;
    //    foreach( PExpr e; mArguments ){
    //        tis ~= e.mResolvedTypeInst;
    //    }
    //    mResolvedCallable = findCallable( mName, tis, !mModifiers.mStatic );
    //}

}
class PExprQuestion : PExpr {
    mixin PartStdImpl!true;
    PExpr  mCond;
    PExpr  mTCase;
    PExpr  mFCase;

    override char[] toUtf8(){
        return(Layouter("PExprQuestion ({0}) ? ({1}) : ({2}): ", mCond.toUtf8, mTCase.toUtf8, mFCase.toUtf8));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mCond is aChild) {
            mCond = aNewExpr;
            return;
        }
        if (mTCase is aChild) {
            mTCase = aNewExpr;
            return;
        }
        if (mFCase is aChild) {
            mFCase = aNewExpr;
            return;
        }
        assert(false);
    }
}
class PExprInstanceof : PExpr {
    mixin PartStdImpl!true;
    PExpr     mExpr;
    PTypeInst mTypeInst;
    override char[]    toUtf8(){
        return(Layouter("PExprInstanceof ({0}) instanceof ({2})", mExpr.toUtf8, mTypeInst.toUtf8));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mExpr is aChild) {
            mExpr = aNewExpr;
            return;
        }
        assert(false);
    }
}
class PExprBinary : PExpr {
    mixin PartStdImpl!true;
    char[] mOp;
    PExpr  mLExpr;
    PExpr  mRExpr;
    override char[] toUtf8(){
        return(Layouter("PExprBinary ({0}) {1} ({2})", mLExpr.toUtf8, mOp, mRExpr.toUtf8));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mLExpr is aChild) {
            mLExpr = aNewExpr;
            return;
        }
        if (mRExpr is aChild) {
            mRExpr = aNewExpr;
            return;
        }
        assert(false);
    }
}
class PExprUnary : PExpr {
    mixin PartStdImpl!true;
    char[] mOp;
    bool   mPost;
    PExpr  mExpr;
    override char[] toUtf8(){
        return(Layouter(mPost ? "PExprPost ({0}){1}" : "PExprPost {1}({0})", mExpr.toUtf8, mOp));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mExpr is aChild) {
            mExpr = aNewExpr;
            return;
        }
        assert(false);
    }
}
class PExprNew : PExpr {
    mixin PartStdImpl!true;
    PTypeRef mTypeRef;
    PExpr[]  mArguments;
    PCtor    mResolvedCtor;
    override char[]   toUtf8(){
        return(Layouter("PExprNew "));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        foreach (inout PExpr arg; mArguments) {
            if (arg is aChild) {
                arg = aNewExpr;
                return;
            }
        }
        assert(false);
    }
    public void resolveCtor(){
        PTypeInst[] tis;
        foreach( PExpr e; mArguments ){
            tis ~= e.mResolvedTypeInst;
        }
        mResolvedCtor = cast( PCtor) (cast(PClassDef)mResolvedTypeInst.mTypeRef.mResolvedTypeDef). findCallable( "this", tis, true );
        assert( mResolvedCtor !is null, mTypeRef.toUtf8 );
    }
}
class PExprNewArray : PExpr {
    mixin PartStdImpl!true;
    PTypeRef      mTypeRef;
    PArrayDecl[]  mArrayDecls;
    PVarInitArray mInitializer;
    override char[]        toUtf8(){
        return(Layouter("PExprNewArray "));
    }
}
class PArrayDecl : PPart {
    mixin PartStdImpl!true;
    PExpr  mCount;
    char[] toUtf8(){
        return(Layouter("PArrayDecl "));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (aChild is mCount) {
            mCount = aNewExpr;
            return;
        }
        assert(false);
    }
}

class PExprNewAnon : PExprNew {
    mixin PartStdImpl!true;
    PClassDef mClassDef;
    override char[]    toUtf8(){
        return(Layouter("PExprNewAnon "));
    }
}
class PExprAssign : PExpr {
    mixin PartStdImpl!true;
    char[] mOp;
    PExpr  mLExpr;
    PExpr  mRExpr;
    override char[] toUtf8(){
        return(Layouter("[PExprAssign mLExpr={0} mOp='{1}' mRExpr={2}]", mLExpr.toUtf8(), mOp, mRExpr.toUtf8()));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mLExpr is aChild) {
            mLExpr = aNewExpr;
            return;
        }
        if (mRExpr is aChild) {
            mRExpr = aNewExpr;
            return;
        }
        assert(false);
    }
}

class PExprIndexOp : PExpr {
    mixin PartStdImpl!true;
    PExpr  mRef;
    PExpr  mIndex;
    override char[] toUtf8(){
        return(Layouter("[PExprIndexOp]"));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mRef is aChild) {
            mRef = aNewExpr;
            return;
        }
        if (mIndex is aChild) {
            mIndex = aNewExpr;
            return;
        }
        assert(false);
    }
}

class PExprTypecast : PExpr {
    mixin PartStdImpl!true;
    PExpr     mExpr;
    PTypeInst mTypeInst;
    override char[]    toUtf8(){
        return(Layouter("PExprTypecast "));
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mExpr is aChild) {
            mExpr = aNewExpr;
            return;
        }
        assert(false);
    }
}

enum LiteralType : int {
    NUM_INT,
    NUM_FLOAT,
    NUM_DOUBLE,
    NUM_LONG,
    CHAR_LITERAL,
    STRING_LITERAL,
    LITERAL_true,
    LITERAL_false,
    LITERAL_null,
    LITERAL_class,
    LITERAL_super,
    LITERAL_this
}
class PExprLiteral : PExpr {
    mixin PartStdImpl!true;
    LiteralType mType;
    char[]      mText;
    override char[]      toUtf8(){
        return(Layouter("PExprLiteral text:{0} type:{1}", mText, cast(int)mType));
    }
}

abstract class PVarInitializer : PExpr {
    mixin PartStdImpl!true;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        assert(false);
    }
    override char[]      toUtf8(){
        return(Layouter("PVarInitializer "));
    }
}

class PVarInitExpr : PVarInitializer {
    mixin PartStdImpl!true;
    PExpr mExpr;

    public this(){
    }

    public this( PExpr e ){
        mExpr = e;
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mExpr is aChild) {
            mExpr = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[]      toUtf8(){
        return(Layouter("PVarInitExpr {0}", mExpr.toUtf8() ));
    }
}
class PVarInitArray : PVarInitializer {
    mixin PartStdImpl!true;
    PVarInitializer[] mInitializers;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        foreach (PVarInitializer i; mInitializers) {
            if (i is aChild) {
                PVarInitializer n = cast(PVarInitializer)aNewExpr;
                assert(n !is null);
                i = n;
                return;
            }
        }
        assert(false);
    }
    override char[]      toUtf8(){
        return(Layouter("PVarInitArray "));
    }
}



abstract class PStatement : PPart, IScope {
    mixin PartStdImpl!(true);

    PPackage findChildPackage(char[] aName){
        return(null);
    }
    PTypeDef findChildTypeDef(char[] aName){
        return(null);
    }
    PTypeDef findOuterTypeDef(){
        return(null);
    }
    PTypeInst findTypeInst(char[] aName){
        return(null);
    }
    PParameterDef findParameterDef(char[] aName){
        return(null);
    }
    PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
        return(null);
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        assert(false, toUtf8 );
    }
    override void exchangeStat(PStatement aChild, PStatement aNewStat){
        assert(false, toUtf8 );
    }
    char[] toUtf8(){
        return("");
    }
}

class PStatList : PStatement {
    mixin PartStdImpl!true;
    PStatement[] mStats;
    bool         mWithoutScope;


    override PTypeInst findTypeInst(char[] aName){
        foreach (PStatement s; mStats) {
            if (PParameterDef pd = cast(PParameterDef)s) {
                if (pd.mName == aName) {
                    return(pd.mTypeInst);
                }
            }
        }
        return(null);
    }
    override PParameterDef findParameterDef(char[] aName){
        foreach (PStatement s; mStats) {
            if (PParameterDef pd = cast(PParameterDef)s) {
                if (pd.mName == aName) {
                    return(pd);
                }
            }
        }
        return(null);
    }
    override PCallable findCallable(char[] aName, PTypeInst[] aArgTypes, bool aIsInstance){
        return(null);
    }

    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        return exchangeStat( aChild, aNewExpr );
    }

    override void exchangeStat(PStatement aChild, PStatement aNewStat){
        foreach (inout PStatement s; mStats) {
            if (s is aChild) {
                s = aNewStat;
                return;
            }
        }
        assert(false);
    }
    override char[]       toUtf8(){
        return("[PStatList]");
    }
}

class PStatGoto : PStatement {
    mixin PartStdImpl!true;
    char[]     mName;
    override char[]     toUtf8(){
        return("[PStatGoto]");
    }
}
class PStatLabeled : PStatement {
    mixin PartStdImpl!true;
    char[]     mName;
    PStatement mStat;
    override char[]     toUtf8(){
        return("[PStatLabeled]");
    }
}
class PStatIf : PStatement {
    mixin PartStdImpl!true;
    PExpr      mCond;
    PStatement mTCase;
    PStatement mFCase;

    override void exchangeStat(PStatement aChild, PStatement aNewStat){
        if (mTCase is aChild) {
            mTCase = aNewStat;
            return;
        }
        if (mFCase is aChild) {
            mFCase = aNewStat;
            return;
        }
        assert(false);
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mCond is aChild) {
            mCond = aNewExpr;
            return;
        }
        aNewExpr.mAsStatement = true;
        if (mTCase is aChild) {
            mTCase = aNewExpr;
            return;
        }
        if (mFCase is aChild) {
            mFCase = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[]     toUtf8(){
        return("[PStatIf]");
    }
}
class PStatFor : PStatement {
    mixin PartStdImpl!true;
    PVarDef[]  mInit_VarDefs;
    PExpr[]    mInit_Exprs;
    PExpr      mCondition;
    PExpr[]    mIterator;
    PStatement mStat;

    override PTypeInst findTypeInst(char[] aName){
        foreach (PVarDef v; mInit_VarDefs) {
            if (v.mName == aName) {
                return(v.mTypeInst);
            }
        }
        return(null);
    }
    override PParameterDef findParameterDef(char[] aName){
        foreach (PVarDef v; mInit_VarDefs) {
            if (v.mName == aName) {
                return(v);
            }
        }
        return(null);
    }

    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mCondition is aChild) {
            mCondition = aNewExpr;
            return;
        }
        foreach (inout PExpr e; mInit_Exprs) {
            if (e is aChild) {
                e = aNewExpr;
                return;
            }
        }
        foreach (inout PExpr e; mIterator) {
            if (e is aChild) {
                e = aNewExpr;
                return;
            }
        }
        if (mStat is aChild) {
            aNewExpr.mAsStatement = true;
            mStat = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[]     toUtf8(){
        return("[PStatFor]");
    }
}
class PStatForeach : PStatement {
    mixin PartStdImpl!true;
    PParameterDef mParam;
    PExpr         mRange;
    PStatement    mStat;

    override PTypeInst findTypeInst(char[] aName){
        if (mParam.mName == aName) {
            return(mParam.mTypeInst);
        }
        return(null);
    }
    override PParameterDef findParameterDef(char[] aName){
        if (mParam.mName == aName) {
            return(mParam);
        }
        return(null);
    }
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mRange is aChild) {
            mRange = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[]        toUtf8(){
        return("[PStatForeach]");
    }
}
class PStatWhile : PStatement {
    mixin PartStdImpl!true;
    PStatement mTodo;
    PExpr      mCond;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mCond is aChild) {
            mCond = aNewExpr;
            return;
        }
        if (mTodo is aChild) {
            aNewExpr.mAsStatement = true;
            mTodo = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[]     toUtf8(){
        return("[PStatWhile]");
    }
}
class PStatDo : PStatement {
    mixin PartStdImpl!true;
    PStatement mTodo;
    PExpr      mCond;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mCond is aChild) {
            mCond = aNewExpr;
            return;
        }
        if (mTodo is aChild) {
            aNewExpr.mAsStatement = true;
            mTodo = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[]     toUtf8(){
        return("[PStatDo]");
    }
}
class PStatBreak : PStatement {
    mixin PartStdImpl!true;
    char[] mName;
    override char[] toUtf8(){
        return("[PStatBreak]");
    }
}
class PStatContinue : PStatement {
    mixin PartStdImpl!true;
    char[] mName;
    override char[] toUtf8(){
        return("[PStatContinue]");
    }
}
class PStatReturn : PStatement {
    mixin PartStdImpl!true;
    PExpr  mValue;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mValue is aChild) {
            mValue = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[] toUtf8(){
        return("[PStatReturn]");
    }
}
class PStatSwitch : PStatement {
    mixin PartStdImpl!true;
    PExpr        mSwitch;
    PCaseGroup[] mCaseGroups;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mSwitch is aChild) {
            mSwitch = aNewExpr;
            return;
        }
        foreach (PCaseGroup cg; mCaseGroups) {
            if (cg.exchangeExpr(aChild, aNewExpr)) {
                return;
            }
        }
        assert(false);
    }
    override char[]       toUtf8(){
        return("[PStatSwitch]");
    }
}
class PCaseGroup {
    bool      mIsDefault;
    PExpr[]   mCases;
    PStatList mTodo;
    bool exchangeExpr(PExpr aChild, PExpr aNewExpr){
        foreach (inout PExpr e; mCases) {
            if (e is aChild) {
                e = aNewExpr;
                return(true);
            }
        }
        return(false);
    }
}
class PStatThrow : PStatement {
    mixin PartStdImpl!true;
    PExpr  mExpr;

    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mExpr is aChild) {
            mExpr = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[] toUtf8(){
        return("[PStatThrow]");
    }
}
class PStatSynchronized : PStatement {
    mixin PartStdImpl!true;
    PExpr      mWith;
    PStatement mWhat;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mWith is aChild) {
            mWith = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[]     toUtf8(){
        return("[PStatSynchronized]");
    }
}
class PStatTry : PStatement {
    mixin PartStdImpl!true;
    PStatList    mTodo;
    PStatCatch[] mHandlers;
    PStatFinally mFinally;
    override char[]       toUtf8(){
        return("[PStatTry]");
    }
}
class PStatCatch : PStatement {
    mixin PartStdImpl!true;
    PParameterDef mParam;
    PStatList     mTodo;

    override PTypeInst findTypeInst(char[] aName){
        if (mParam.mName == aName) {
            return(mParam.mTypeInst);
        }
        return(super.findTypeInst(aName));
    }
    override PParameterDef findParameterDef(char[] aName){
        if (mParam.mName == aName) {
            return(mParam);
        }
        return(super.findParameterDef(aName));
    }
    override char[]        toUtf8(){
        return("[PStatCatch]");
    }
}
class PStatFinally : PStatement {
    mixin PartStdImpl!true;
    PStatList mTodo;
    override char[]    toUtf8(){
        return("[PStatFinally]");
    }
}
class PStatAssert : PStatement {
    mixin PartStdImpl!true;
    PExpr  mCond;
    PExpr  mMsg;
    override void exchangeExpr(PExpr aChild, PExpr aNewExpr){
        if (mCond is aChild) {
            mCond = aNewExpr;
            return;
        }
        if (mMsg is aChild) {
            mMsg = aNewExpr;
            return;
        }
        assert(false);
    }
    override char[] toUtf8(){
        return("[PStatAssert]");
    }
}


