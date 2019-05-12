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
module Resolve;

import Parts;
import PartVisitor;
import Refactorings;
import Utils;

import tango.io.Stdout;

/**
 * Go through the data and resolve all references.
 * This means, insert links to the type/variable definitions and delete the referencing identifier values.
 */

void resolveStage1(){
    initializeWellKnownTypes();

    auto resolver = new BaseTypeResolver();
    getPackageRoot().accept(resolver);
    if( resolver.hadErrors()){
        throw new ResolveException( "Errors exist" );
    }
}

void resolveStage2(){
    auto resolver = new VarTypeResolver();

    getPackageRoot().accept( resolver );
    if( resolver.hadErrors()){
        throw new ResolveException( "Errors exist" );
    }
}

void resolveStage3(){
    getPackageRoot().accept(new ExprResolver());
}


class ResolveException : Exception {
    this(char[] aMsg){
        super(aMsg);
    }
}

abstract class Resolver : PartTraversVisitor {
    alias  PartTraversVisitor.visit visit;
    private bool mHadErrors = false;
    public bool hadErrors(){
        return mHadErrors;
    }

    char[] mResolverName;
    public this(char[] aResolverName){
        mResolverName = aResolverName;
    }

    override void visit(PModule p){
        //Stdout.formatln(" *** {0} in Module {1}", mResolverName, p.getFqn());
        super.visit(p);
    }

    void resolveTypeRef(IScope scp, PTypeRef aTypeRef){
        try{
            assert(aTypeRef !is null);
            if( aTypeRef.mResolvedTypeDef !is null ){
                //Stdout.formatln( "{0}", aTypeRef.mResolvedTypeDef.toUtf8 );
            }
            assert( aTypeRef.mParts.length > 0, aTypeRef.toUtf8() );

            void check(bool aCond){
                if (!aCond) {
                    throw new ResolveException(Layouter("Resolver: Cannot resolve {0} in Module {1}", aTypeRef.getString(), mModule.getFqn()));
                }
            }

            //Stdout.formatln("resolveTypeRef {0} {1} scp={2}", mModule.getFqn, aTypeRef.getString(), (cast(Object)scp).toUtf8() );
            PTypeDef curTypeDef;
            PTypeDef o = mTypeDef;
            //cast(PTypeDef)scp;
            //if( o is null ){
            //    o = scp.findOuterTypeDef;
            //}
            //if( o is null ){
            //    o = mTypeDef;
            //}
            while (o !is null) {
                curTypeDef = o.findChildTypeDef(aTypeRef.mParts[0].mText.dup);
                if (curTypeDef !is null) {
                    break;
                }
                o = o.findOuterTypeDef();
            }
            if (curTypeDef is null) {
                // try package level
                assert( mPackage !is null );
                curTypeDef = mPackage.findChildTypeDef(aTypeRef.mParts[0].mText.dup);
            }
            if (curTypeDef is null) {
                // try module level, this includes the imported types
                curTypeDef = mModule.findImportedTypeDef(aTypeRef.mParts[0].mText.dup);
            }
            if (curTypeDef is null) {
                // try global level
                curTypeDef = mRoot.findChildTypeDef(aTypeRef.mParts[0].mText.dup);
            }
            int index = 1;
            if (curTypeDef is null) {
                // fqn
                //Stdout.formatln("fqn");
                PPackage curPackage = mRoot;
                PModule  mod;
                for (int i = 0; i < aTypeRef.mParts.length; i++) {
                    index = i + 1;
                    PTypeRefPart part = aTypeRef.mParts[i];

                    PPackage     p = curPackage.findChildPackage(part.mText.dup);
                    if (p is null) {
                        curTypeDef = curPackage.findChildTypeDef(part.mText.dup);
                        break;
                    }
                    curPackage = p;
                }
                check(curTypeDef !is null);
            }
            for (int i = index; i < aTypeRef.mParts.length; i++) {
                PTypeRefPart part = aTypeRef.mParts[i];
                //Stdout.formatln( "try resolving {0} ", part.mText.dup );
                curTypeDef = curTypeDef.findChildTypeDef(part.mText.dup);
                check(curTypeDef !is null);
            }
            aTypeRef.mResolvedTypeDef = curTypeDef;
            assert(aTypeRef.mResolvedTypeDef !is null);
        }
        catch( ResolveException e ){
            Stdout.formatln( e.msg );
            mHadErrors = true;
        }
    }

    void resolveTypeInst(IScope scp, PTypeInst aTypeInst){
        assert(aTypeInst  !is null);
        resolveTypeRef(scp, aTypeInst.mTypeRef);
        //assert(aTypeInst.mTypeRef.mResolvedTypeDef !is null);
    }

    PTypeInst resolveFieldOrTypeRef(IScope aScope, char[] aName){
        //Stdout.formatln("resolveFieldOrTypeRef in {0}, search for {1}", (cast(Object)aScope).toUtf8, aName);
        // Variabel/Field ?
        if (PTypeInst ti = aScope.findTypeInst(aName)) {
            //Stdout.formatln("resolveFieldOrTypeRef in {0}, found var or field", (cast(Object)aScope).toUtf8);
            ti.mIsInstance = true;
            return(ti);
        }

        //Stdout.formatln("resolveFieldOrTypeRef in {0}, start type search", (cast(Object)aScope).toUtf8);
        // Type search
        // Outer class ?
        PTypeDef curTypeDef;
        PTypeDef o = aScope.findOuterTypeDef();
        while (o !is null) {
            //Stdout.formatln("Looking at outer typedef {0}", o.mName);
            curTypeDef = o.findChildTypeDef(aName);
            if (curTypeDef !is null) {
                break;
            }
            o = o.findOuterTypeDef();
        }
        if (curTypeDef is null) {
            // try package level
            curTypeDef = mPackage.findChildTypeDef(aName);
        }
        if (curTypeDef is null) {
            // try module level, this includes the imported types
            curTypeDef = mModule.findImportedTypeDef(aName);
        }
        if (curTypeDef is null) {
            // try global level
            curTypeDef = mRoot.findChildTypeDef(aName);
        }
        if (curTypeDef !is null) {
            PTypeInst ti = new PTypeInst;
            ti.mTypeRef.mResolvedTypeDef = curTypeDef;
            ti.mIsInstance               = false;
            return(ti);
        }
        return(null);
    }
}

/**
 * Resolve all super classes und implemented interfaces. This is a precondition for all following
 * resolving, because of possibly derived methods and fields.
 */
class BaseTypeResolver : Resolver {
    alias Resolver.visit visit;
    int getTraceLevel(){
        return(1);
    }
    this(){
        super("Resolve base types");
    }
    override void visit(PImport p){
        PPackage s = mRoot;

        void check(bool aCond){
            if (!aCond) {
                throw new ResolveException(Layouter("BaseTypeResolver: Cannot resolve import {0} in Module {1}", p.getFqn(), mModule.getFqn()));
            }
        }

        try{
            PModule  mod;
            foreach (char[] part; p.mTexts) {
                // extra part!!
                check(mod is null);
                PPackage pack = s.findChildPackage(part);
                if (pack !is null) {
                    s = pack;
                }
                else {
                    mod = s.findChildModule(part);
                    if( mod is null && (mModule.mIsNowrite || mModule.mIsStub ) ){
                        return;
                    }
                    check(mod !is null);

                    // s is module scope, must contain a typedef called equal
                    mModule.mVsibileTypeDefs ~= mod.findChildTypeDef(mod.mName);
                    return;
                }
            }
            // if not completely resolved it has to be a star
            check(p.mStar);
            foreach (PModule smod; s.mModules) {
                mModule.mVsibileTypeDefs ~= smod.mTypeDefs;
            }
        }catch( ResolveException e ){
            Stdout.formatln( "{}", e.msg );
            mHadErrors = true;
        }
    }


    override void visit(PPackage p){
        mPackage = p;
        super.visit(p);
    }

    override void visit(PModule p){
        mModule = p;
        super.visit(p);
    }

    override void visit(PInterfaceDef p){
        foreach (PTypeRef tr; p.mSuperIfaces) {
            resolveTypeRef(p, tr);
        }
        super.visit(p);
    }

    override void visit(PClassDef p){
        if (p.mSuperClass) {
            resolveTypeRef(p, p.mSuperClass);
        }
        foreach (PTypeRef tr; p.mSuperIfaces) {
            resolveTypeRef(p, tr);
        }
        super.visit(p);
    }

    override void visit(PExprNewAnon p){
        super.visit(p);
        resolveTypeRef(p, p.mTypeRef);
        if( mHadErrors ){
            return;
        }
        if (PClassDef t = cast(PClassDef)p.mTypeRef.mResolvedTypeDef) {
            p.mClassDef.mSuperClass = p.mTypeRef;
        }
        else if (PInterfaceDef t = cast(PInterfaceDef)p.mTypeRef.mResolvedTypeDef) {
            p.mClassDef.mSuperIfaces ~= p.mTypeRef;
        }
        else {
            assert(false);
        }
    }
}

class VarTypeResolver : Resolver {
    alias Resolver.visit visit;

    int getTraceLevel(){
        return(1);
    }
    this(){
        super("Resolve var types");
    }
    PClassDef classDef;
    override void visit(PClassDef p){
        PClassDef bak = classDef;
        classDef = p;
        super.visit(p);
        classDef = bak;
    }
    override void visit(PMethodDef p){
        resolveTypeInst(mTypeDef, p.mReturnType);
        super.visit(p);
    }
    override void visit(PParameterDef p){
        super.visit(p);
        resolveTypeInst(mTypeDef, p.mTypeInst);
    }
    override void visit(PVarDef p){
        resolveTypeInst(mTypeDef, p.mTypeInst);
        super.visit(p);
    }
    override void visit(PFieldDef p){
        if( isArrayTypeDef( classDef ) && p.mName == "length" ){
            p.mTypeInst = new PTypeInst( gBuildinTypeUInt, 0, true );
        }
        else{
            resolveTypeInst(mTypeDef, p.mTypeInst);
        }
        super.visit(p);
    }
    override void visit(PLocalVarDef p){
        resolveTypeInst(mTypeDef, p.mTypeInst);
        assert(p.mTypeInst.mTypeRef.mResolvedTypeDef !is null);
        super.visit(p);
    }
}

class ExprResolver : Resolver {
    alias Resolver.visit visit;
    int getTraceLevel(){
        return(4);
    }
    this(){
        super("Resolve expressions");
    }
    PParameterDef tryResolveParameterDef(char[] aName){
        TScopeList lst = getScopeList();

        while (lst.size() > 0) {
            IScope        scp = lst.take();
            PParameterDef pd  = scp.findParameterDef(aName);
            if (pd !is null) {
                return(pd);
            }
        }
        return(null);
    }
    PTypeInst tryResolveIdent(char[] aName){
        TScopeList lst = getScopeList();

        while (lst.size() > 0) {
            IScope    scp = lst.take();
            PTypeInst ti  = resolveFieldOrTypeRef(scp, aName);
            if (ti !is null) {
                return(ti);
            }
        }
        return(null);
    }

    // local variables can override fields, BUT only after they appear.
    override void visit(PStatList p){
        pushScope(p);
        PStatement[] tempStats;
        tempStats = p.mStats;
        p.mStats  = null;
        foreach (PStatement s; tempStats) {
            p.mStats ~= s;
            goVisitPart(p, s);
        }
        p.mStats = tempStats;
        popScope();
    }

    override void visit(PExprIdent p){
        // a sole identifier must be a variable, field, parameter
        //Stdout.formatln( "ident {0}: {1}", mModule.getFqn(), p.mName );
        if (PParameterDef pd = tryResolveParameterDef(p.mName)) {
            assert(pd.mTypeInst !is null);
            assert(pd.mTypeInst.mTypeRef !is null);
            assert(pd.mTypeInst.mTypeRef.mResolvedTypeDef !is null);
            PExprVarRef eexpr = new PExprVarRef(pd);
            assert(eexpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);
            p.mPartParent.exchangeExpr(p, eexpr);
            return;
        }
        if (PTypeInst ti = tryResolveIdent(p.mName)) {
            PExprTypeInst eexpr = new PExprTypeInst;
            eexpr.mResolvedTypeInst = ti;
            p.mPartParent.exchangeExpr(p, eexpr);
            return;
        }
        assert(p.mAllowNonResolve, scopeStackToUtf8() ~ " p.mName:" ~ p.mName ~ " in mod " ~ mModule.getFqn());
    }
    override void visit(PExprDot e){
        if (PExprIdent lident = cast(PExprIdent)e.mLExpr) {
            lident.mAllowNonResolve = true;
            goVisitPart(e, lident);
            // if the identifier didn't change into PExprTypeInst or PExprVarRef, this means
            // that it can be a global type or FQN

            if (e.mLExpr.mResolvedTypeInst is null) {
                if (PTypeDef td = mRoot.findChildTypeDef(lident.mName)) {
                    e.mLExpr                   = new PExpr;
                    e.mLExpr.mResolvedTypeInst = new PTypeInst(td, 0, false);
                }
            }

            if (e.mLExpr.mResolvedTypeInst is null) {
                // must be FQN top package ref
                PPackage pack = mRoot.findChildPackage(lident.mName);
                assert(pack !is null, lident.mName);

                if (PExprIdent rident = cast(PExprIdent)e.mRExpr) {
                    // then R must be Type or Package of p
                    if (PTypeInst ti = resolveFieldOrTypeRef(pack, rident.mName)) {
                        e.mRExpr.mResolvedTypeInst = ti;

                        // found fqn, add to imports
                        //Stdout.formatln( "found FQN in {0}: {1}", mModule.getFqn(), ti.getString() );
                        assert(ti.mTypeRef.mResolvedTypeDef !is null);
                        mModule.mVsibileTypeDefs ~= ti.mTypeRef.mResolvedTypeDef;
                    }
                    else {
                        e.mResolvedPackage = pack.findChildPackage(rident.mName);
                        assert(e.mResolvedPackage !is null, lident.mName ~ "." ~ rident.mName ~ "    " ~ scopeStackToUtf8() );
                    }
                }
                else {
                    assert(false);
                }
            }
            else {
                assert(e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);

                pushScope(e.mLExpr.mResolvedTypeInst);
                goVisitPart(e, e.mRExpr);
                popScope();
                if (e.mRExpr.mResolvedTypeInst.mIsInstance == false) {
                    PExpr eexpr = new PExpr;
                    eexpr.mResolvedTypeInst = e.mRExpr.mResolvedTypeInst;
                    e.mPartParent.exchangeExpr(e, eexpr);
                }
                else if( PExprVarRef vref = cast(PExprVarRef)e.mRExpr ){

                    e.mResolvedTypeInst = e.mRExpr.mResolvedTypeInst;

                    if( !e.mLExpr.mResolvedTypeInst.mIsInstance ){
                        vref.mFromTypeDef = e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef;
                    }
                    else{
                        vref.mExprReference = e.mLExpr;
                    }
                    //vref.mExprReference = e.mLExpr;
                    e.mPartParent.exchangeExpr( e, vref );
                }
                else {
                    e.mResolvedTypeInst = e.mRExpr.mResolvedTypeInst;
                }
            }
        }
        else if (PExprDot ldot = cast(PExprDot)e.mLExpr) {
            goVisitPart(e, e.mLExpr);

            if (PTypeInst lti = ldot.mResolvedTypeInst) {
                assert(lti.mTypeRef.mResolvedTypeDef !is null);
                pushScope(lti);
                goVisitPart(e, e.mRExpr);
                popScope();
                PTypeInst rti = e.mRExpr.mResolvedTypeInst;
                assert(rti !is null, e.mRExpr.toUtf8());
                assert(rti.mTypeRef.mResolvedTypeDef !is null, Layouter("{0} in {1}", e.mRExpr.toUtf8(), mModule.getFqn()));
                e.mResolvedTypeInst = rti;
                if( PExprVarRef vr = cast(PExprVarRef) e.mRExpr ){
                    if( !lti.mIsInstance ){
                        vr.mFromTypeDef = lti.mTypeRef.mResolvedTypeDef;
                    }
                    else{
                        vr.mExprReference = e.mLExpr;
                    }
                    e.mPartParent.exchangeExpr(e, vr);
                }
            }
            else if (PPackage pack = ldot.mResolvedPackage) {
                PExprIdent rident = cast(PExprIdent)e.mRExpr;
                assert(rident !is null);
                //if (PTypeInst ti = resolveFieldOrTypeRef(pack, rident.mName)) {
                if (PTypeDef td = pack.findChildTypeDef( rident.mName)) {
                    PTypeInst ti = new PTypeInst( td, 0, false );
                    e.mRExpr.mResolvedTypeInst = ti;
                    e.mResolvedTypeInst        = ti;

                    // found fqn, add to imports
                    //Stdout.formatln( "found FQN in {0}: {1}", mModule.getFqn(), ti.getString() );
                    assert(ti.mTypeRef.mResolvedTypeDef !is null);
                    mModule.mVsibileTypeDefs ~= ti.mTypeRef.mResolvedTypeDef;
                    //Stdout.formatln( "left Pack, rident = {0}, {1}", rident.mName, scopeStackToUtf8 );
                    PExprTypeInst eti = new PExprTypeInst;
                    eti.mResolvedTypeInst = ti;
                    e.mPartParent.exchangeExpr(e, eti);
                }
                else {
                    e.mResolvedPackage = pack.findChildPackage(rident.mName);
                    if( e.mResolvedPackage is null ){
                        throw new Exception( Layouter( "ExpressionResolver: Cannot resolve {0} in package {1}.", rident.mName, pack.getFqn ));
                    }
                    assert(e.mResolvedPackage !is null, Layouter( "{0}   {1}", rident.mName, scopeStackToUtf8 ) );
                }
            }
            else {
                assert(false);
            }
        }
        else {
            goVisitPart(e, e.mLExpr);
            PTypeInst ti = e.mLExpr.mResolvedTypeInst;
            assert(ti !is null, e.mLExpr.toUtf8());
            assert(ti.mTypeRef.mResolvedTypeDef !is null, e.mLExpr.toUtf8());
            //Stdout.formatln("set type context to {0}", ti.mTypeRef.mResolvedTypeDef.getFqn());
            pushScope(ti);
            goVisitPart(e, e.mRExpr);
            popScope();
            ti = e.mRExpr.mResolvedTypeInst;
            assert(ti !is null, e.mRExpr.toUtf8());
            assert(ti.mTypeRef.mResolvedTypeDef !is null, Layouter("{0} in {1}", e.mRExpr.toUtf8(), mModule.getFqn()));
            e.mResolvedTypeInst = ti;

            if( PExprVarRef vref = cast(PExprVarRef)e.mRExpr ){

                vref.mExprReference = e.mLExpr;
                e.mPartParent.exchangeExpr( e, vref );
            }
            //Stdout.formatln(" expr dot ");
        }
    }

    override void visit(PExprLiteral e){
        PTypeInst ti = new PTypeInst;

        ti.mIsInstance      = true;
        e.mResolvedTypeInst = ti;
        switch (e.mType) {
        case LiteralType.NUM_INT:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeInt;
            return;

        case LiteralType.NUM_FLOAT:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeFloat;
            return;

        case LiteralType.NUM_DOUBLE:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeDouble;
            return;

        case LiteralType.NUM_LONG:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeLong;
            return;

        case LiteralType.CHAR_LITERAL:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeChar;
            return;

        case LiteralType.LITERAL_true:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeBoolean;
            return;

        case LiteralType.LITERAL_false:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeBoolean;
            return;

        case LiteralType.STRING_LITERAL:
            ti.mTypeRef.mResolvedTypeDef = gTypeJavaLangString;
            return;

        case LiteralType.LITERAL_null:
            ti.mTypeRef.mResolvedTypeDef = gBuildinTypeNull;
            return;

        case LiteralType.LITERAL_this:
            PExprVarRef evref       = new PExprVarRef;
            evref.mParameterDef     = (cast(PClassDef)mTypeDef).mThis;
            evref.mResolvedTypeInst = evref.mParameterDef.mTypeInst;
            e.mPartParent.exchangeExpr(e, evref);
            return;

        case LiteralType.LITERAL_super:
            PExprVarRef evref = new PExprVarRef;
            PClassDef refThis  = cast(PClassDef)mTypeDef;
            PClassDef refSuper = cast(PClassDef)refThis.mSuperClass.mResolvedTypeDef;
            evref.mParameterDef     = refSuper.mThis;
            evref.mIsSuperRef       = true;
            evref.mResolvedTypeInst = evref.mParameterDef.mTypeInst;
            e.mPartParent.exchangeExpr(e, evref);
            return;

        case LiteralType.LITERAL_class:
            PExprVarRef evref       = new PExprVarRef;
            evref.mParameterDef     = (cast(PClassDef)mTypeDef).mClass;
            evref.mResolvedTypeInst = evref.mParameterDef.mTypeInst;
            e.mPartParent.exchangeExpr(e, evref);
            return;

        default:
            assert(false, e.mText);
            return;
        }
    }

    override void visit(PVarInitializer p){
        super.visit(p);
    }
    override void visit(PVarInitExpr p){
        super.visit(p);
        p.mResolvedTypeInst = p.mExpr.mResolvedTypeInst;
    }
    override void visit(PVarInitArray p){
        // take type of first element

        //if( p.mInitializers.length > 0 ){
        //    p.mResolvedTypeInst = p.mInitializers[0].mResolvedTypeInst.clone;
        //    p.mResolvedTypeInst.mDimensions++;
        //}
        //else 

        if( PVarDef par = cast(PVarDef) p.mPartParent ){
            if( par.mInitializer is p ){
                // in case of this java variable initialization:
                // int blockStarts[] = {};
                // take the type of lval
                p.mResolvedTypeInst = par.mTypeInst;
                assert( p.mResolvedTypeInst !is null, scopeStackToUtf8() );
                //Stdout.print( "varinit type from assign lval: " ~ scopeStackToUtf8() ~ " p.mPartParent:" ~ p.mPartParent.toUtf8() ~ " p:" ~ p.toUtf8() );
            }
        }
        else if( PParameterDef par = cast(PParameterDef) p.mPartParent ){
            // nothing, let the parent do the job
        }
        else if( PExprNewArray par = cast(PExprNewArray) p.mPartParent ){
            // nothing, let the parent do the job
        }
        else if( PVarInitArray par = cast(PVarInitArray) p.mPartParent ){
            p.mResolvedTypeInst = par.mResolvedTypeInst.clone;
            p.mResolvedTypeInst.mDimensions--;
            assert( p.mResolvedTypeInst.mDimensions >= 0 );
        }
        else if( PExprAssign par = cast(PExprAssign) p.mPartParent ){
            assert( par.mRExpr is p );
            // in case of this java variable initialization:
            // blockStarts[] = {};
            // take the type of lval
            p.mResolvedTypeInst = par.mLExpr.mResolvedTypeInst;
            assert( p.mResolvedTypeInst !is null, scopeStackToUtf8() );
            //Stdout.print( "varinit type from assign lval: " ~ scopeStackToUtf8() ~ " p.mPartParent:" ~ p.mPartParent.toUtf8() ~ " p:" ~ p.toUtf8() );
        }
        else{
            //assert( false, scopeStackToUtf8() ~ " p.mPartParent:" ~ p.mPartParent.toUtf8() ~ " p:" ~ p.toUtf8() );
        }
        super.visit(p);
    }
    override void visit(PExprBinary e){
        super.visit(e);
        switch (e.mOp) {
        case "||":
        case "&&":
        case "!=":
        case "==":
        case "<":
        case ">":
        case "<=":
        case ">=":

            switch (e.mOp) {
            case "==":
                e.mOp = "is"; break;

            case "!=":
                e.mOp = "!is"; break;

            default:
                break;
            }
            e.mResolvedTypeInst = new PTypeInst(gBuildinTypeBoolean, 0, true);
            break;

        case "+":
            assert(e.mLExpr !is null);
            assert(e.mLExpr.mResolvedTypeInst !is null, e.mLExpr.toUtf8());
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);

            assert(e.mRExpr !is null);
            assert(e.mRExpr.mResolvedTypeInst !is null, e.mRExpr.toUtf8());
            assert(e.mRExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(e.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);

            if ((e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef is gTypeJavaLangString) ||
                (e.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef is gTypeJavaLangString)) {
                e.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
                e.mOp               = "~";
                break;
            }

        case "|":
        case "^":
        case "&":
        case "<<":
        case ">>":
        case ">>>":
        case "-":
        case "/":
        case "%":
        case "*":
            assert(e.mLExpr !is null);
            assert(e.mLExpr.mResolvedTypeInst !is null, e.mLExpr.toUtf8());
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null, e.mLExpr.toUtf8() ~ " " ~ e.mLExpr.mResolvedTypeInst.mTypeRef.getString());

            assert(e.mRExpr !is null);
            assert(e.mRExpr.mResolvedTypeInst !is null, e.mRExpr.toUtf8());
            assert(e.mRExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(e.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);

            PBuildinType l = cast(PBuildinType)e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef;
            assert(l !is null, e.mLExpr.toUtf8());
            PBuildinType r = cast(PBuildinType)e.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef;
            assert(r !is null, e.mRExpr.toUtf8());
            // the resulting type is the "bigger" type
            PBuildinType combined = l > r ? l : r;
            e.mResolvedTypeInst = new PTypeInst(combined, 0, true);
            break;

        default:
            assert(false, e.mOp);
        }
    }
    override void visit(PExprUnary e){
        super.visit(e);
        switch (e.mOp) {
        case "++":
        case "--":
        case "~":
        case "-":
        case "+":
            e.mResolvedTypeInst = new PTypeInst(e.mExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef, 0, true);
            break;

        case "!":
            e.mResolvedTypeInst = new PTypeInst(gBuildinTypeBoolean, 0, true);
            break;

        default:
            assert(false, e.mOp);
        }
    }
    override void visit(PExprMethodCall p){
        //Stdout.formatln( "  * {0}()  >>>", p.mName);
        super.visit(p);
        PTypeDef    td;
        bool        isInstance;
        if (p.mTrgExpr is null) {
            td = mTypeDef;
            //FIXME must evaluate context: static?
            isInstance = true;
            assert(td !is null, p.mName);
        }
        else {
            //Stdout.formatln( "  1 {0}()  >>>", p.mName);
            //    resolveTypeInst( p, p.mTrgExpr.mResolvedTypeInst);
            //Stdout.formatln( "  2 {0}()  >>>", p.mName);
            td         = p.mTrgExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef;
            isInstance = p.mTrgExpr.mResolvedTypeInst.mIsInstance;
            assert(p.mTrgExpr !is null, scopeStackToUtf8() ~p.mName);
            assert(p.mTrgExpr.mResolvedTypeInst !is null, scopeStackToUtf8() ~p.mName);
            assert(p.mTrgExpr.mResolvedTypeInst.mTypeRef !is null, scopeStackToUtf8() ~p.mName);
            assert(td !is null, scopeStackToUtf8() ~p.mName);

            if (p.mTrgExpr.mResolvedTypeInst.mDimensions > 0) {
                td = gTypeJavaLangJArray;
            }
        }
        PTypeInst[] argTypes;
        foreach (PExpr argExpr; p.mArguments) {
            PTypeInst ti = argExpr.mResolvedTypeInst;
            assert(ti !is null, scopeStackToUtf8() ~ " p.mName:" ~ p.mName ~ " argExpr:" ~ argExpr.toUtf8());
            argTypes ~= ti;
        }
        PCallable   callable = td.findCallable(p.mName, argTypes, isInstance);
        assert(callable !is null, p.mName);
        p.mResolvedCallable = callable;
        if (PMethodDef mth = cast(PMethodDef)callable) {
            p.mResolvedTypeInst = mth.mReturnType;
        }
        else {
            p.mResolvedTypeInst = new PTypeInst(gBuildinTypeVoid, 0, false);
        }
    }
    override void visit(PExprInstanceof p){
        super.visit(p);
        resolveTypeInst(p, p.mTypeInst);
        p.mResolvedTypeInst = p.mTypeInst;
    }
    override void visit(PExprQuestion p){
        super.visit(p);
        p.mResolvedTypeInst = p.mTCase.mResolvedTypeInst;
    }
    override void visit(PExprNew p){
        super.visit(p);
        resolveTypeRef(p, p.mTypeRef);
        p.mResolvedTypeInst = new PTypeInst(p.mTypeRef.mResolvedTypeDef, 0, true);
        p.resolveCtor();
    }
    override void visit(PExprNewArray p){
        super.visit(p);
        resolveTypeRef(p, p.mTypeRef);
        p.mResolvedTypeInst = new PTypeInst(p.mTypeRef.mResolvedTypeDef, p.mArrayDecls.length, true);
    }
    override void visit(PExprNewAnon p){
        super.visit(p);
        resolveTypeRef(p, p.mTypeRef);
        p.mResolvedTypeInst = new PTypeInst(p.mClassDef, 0, true);
    }
    override void visit(PExprAssign e){
        super.visit(e);
        switch (e.mOp) {
        case "+=":
            assert(e.mLExpr !is null);
            assert(e.mLExpr.mResolvedTypeInst !is null, e.mLExpr.toUtf8());
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);

            assert(e.mRExpr !is null);
            assert(e.mRExpr.mResolvedTypeInst !is null, e.mRExpr.toUtf8());
            assert(e.mRExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(e.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null);

            if ((e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef is gTypeJavaLangString) ||
                (e.mRExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef is gTypeJavaLangString)) {
                e.mResolvedTypeInst = new PTypeInst(gTypeJavaLangString, 0, true);
                e.mOp               = "~=";
                break;
            }

        case "|=":
        case "^=":
        case "&=":
        case "<<=":
        case ">>=":
        case ">>>=":
        case "-=":
        case "/=":
        case "%=":
        case "*=":
        case "=":
            assert(e.mLExpr !is null);
            assert(e.mLExpr.mResolvedTypeInst !is null, e.mLExpr.toUtf8());
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef !is null);
            assert(e.mLExpr.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null,
                scopeStackToUtf8() ~ " e.mLExpr:" ~ e.mLExpr.toUtf8() ~ " e.mLExpr.mResolvedTypeInst.mTypeRef.getString():" ~ e.mLExpr.mResolvedTypeInst.mTypeRef.getString());

            e.mResolvedTypeInst = e.mLExpr.mResolvedTypeInst;
            break;

        default:
            assert(false, e.mOp);
        }
    }
    override void visit(PExprIndexOp p){
        super.visit(p);
        int dim = p.mRef.mResolvedTypeInst.mDimensions;
        dim--;
        assert(dim >= 0);
        p.mResolvedTypeInst             = new PTypeInst;
        p.mResolvedTypeInst.mTypeRef    = p.mRef.mResolvedTypeInst.mTypeRef;
        p.mResolvedTypeInst.mDimensions = dim;
        assert(p.mResolvedTypeInst.mTypeRef.mResolvedTypeDef !is null, scopeStackToUtf8() ~p.mRef.toUtf8());
        //p.mResolvedTypeInst = p.mRef.mResolvedTypeInst.clone();
    }
    override void visit(PExprTypecast p){
        super.visit(p);
        resolveTypeInst(p, p.mTypeInst);
        p.mResolvedTypeInst = p.mTypeInst;
    }
    override void visit( PModule p ){
        try{
            super.visit(p);
        }
        catch( ResolveException e ){
            Stdout.formatln( "{}", e.msg );
            mHadErrors = true;
        }
    }
}


