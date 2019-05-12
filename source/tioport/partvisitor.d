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
module tioport.partvisitor;

import tioport.parts;
import tioport.utils;

//FIXME
import tango.util.container.LinkedList;
alias LinkSeq = LinkedList;
//import tango.util.collection.LinkSeq;
import tango.io.Stdout;



interface Visitor {
    void visit(PPart p);
    void visit(PPackage p);
    void visit(PRootPackage p);
    void visit(PModule p);
    void visit(PImport p);
    void visit(PTypeDef p);
    void visit(PClassDef p);
    void visit(PInterfaceDef p);
    void visit(PVarDef p);
    void visit(PParameterDef p);
    void visit(PFieldDef p);
    void visit(PLocalVarDef p);
    void visit(PCallable p);
    void visit(PCtor p);
    void visit(PStaticCtor p);
    void visit(PInstanceInit p);
    void visit(PMethodDef p);
    void visit(PVarInitializer p);
    void visit(PVarInitExpr p);
    void visit(PVarInitArray p);
    void visit(PArrayDecl p);
    void visit(PExpr p);
    void visit(PExprVarRef p);
    void visit(PExprFncRef p);
    void visit(PExprTypeInst p);
    void visit(PExprTypecast p);
    void visit(PExprIdent p);
    void visit(PExprDot p);
    void visit(PExprMethodCall p);
    void visit(PExprQuestion p);
    void visit(PExprInstanceof p);
    void visit(PExprBinary p);
    void visit(PExprUnary p);
    void visit(PExprNew p);
    void visit(PExprNewArray p);
    void visit(PExprNewAnon p);
    void visit(PExprAssign p);
    void visit(PExprIndexOp p);
    void visit(PExprLiteral p);
    void visit(PStatement p);
    void visit(PStatList p);
    void visit(PStatLabeled p);
    void visit(PStatGoto p);
    void visit(PStatIf p);
    void visit(PStatFor p);
    void visit(PStatForeach p);
    void visit(PStatWhile p);
    void visit(PStatDo p);
    void visit(PStatBreak p);
    void visit(PStatContinue p);
    void visit(PStatReturn p);
    void visit(PStatSwitch p);
    void visit(PStatThrow p);
    void visit(PStatSynchronized p);
    void visit(PStatTry p);
    void visit(PStatCatch p);
    void visit(PStatFinally p);
    void visit(PStatAssert p);
}
class StdVisitor : Visitor {
    char[] mName;
    protected this(char[] aName){
        mName = aName;
    }
    void visit(PPart p){
        assert(false, mName);
    }
    void visit(PPackage p){
        assert(false, mName);
    }
    void visit(PRootPackage p){
        assert(false, mName);
    }
    void visit(PModule p){
        assert(false, mName);
    }
    void visit(PImport p){
        assert(false, mName);
    }
    void visit(PTypeDef p){
        assert(false, mName);
    }
    void visit(PClassDef p){
        assert(false, mName);
    }
    void visit(PInterfaceDef p){
        assert(false, mName);
    }
    void visit(PVarDef p){
        assert(false, mName);
    }
    void visit(PParameterDef p){
        assert(false, mName);
    }
    void visit(PFieldDef p){
        assert(false, mName);
    }
    void visit(PLocalVarDef p){
        assert(false, mName);
    }
    void visit(PCallable p){
        assert(false, mName);
    }
    void visit(PCtor p){
        assert(false, mName);
    }
    void visit(PStaticCtor p){
        assert(false, mName);
    }
    void visit(PInstanceInit p){
        assert(false, mName);
    }
    void visit(PMethodDef p){
        assert(false, mName);
    }
    void visit(PVarInitializer p){
        assert(false, mName);
    }
    void visit(PVarInitExpr p){
        assert(false, mName);
    }
    void visit(PVarInitArray p){
        assert(false, mName);
    }
    void visit(PArrayDecl p){
        assert(false, mName);
    }
    void visit(PExpr p){
        assert(false, mName);
    }
    void visit(PExprVarRef p){
        assert(false, mName);
    }
    void visit(PExprFncRef p){
        assert(false, mName);
    }
    void visit(PExprTypeInst p){
        assert(false, mName);
    }
    void visit(PExprTypecast p){
        assert(false, mName);
    }
    void visit(PExprIdent p){
        assert(false, mName);
    }
    void visit(PExprDot p){
        assert(false, mName);
    }
    void visit(PExprMethodCall p){
        assert(false, mName);
    }
    void visit(PExprQuestion p){
        assert(false, mName);
    }
    void visit(PExprInstanceof p){
        assert(false, mName);
    }
    void visit(PExprBinary p){
        assert(false, mName);
    }
    void visit(PExprUnary p){
        assert(false, mName);
    }
    void visit(PExprNew p){
        assert(false, mName);
    }
    void visit(PExprNewArray p){
        assert(false, mName);
    }
    void visit(PExprNewAnon p){
        assert(false, mName);
    }
    void visit(PExprAssign p){
        assert(false, mName);
    }
    void visit(PExprIndexOp p){
        assert(false, mName);
    }
    void visit(PExprLiteral p){
        assert(false, mName);
    }
    void visit(PStatement p){
        assert(false, mName);
    }
    void visit(PStatList p){
        assert(false, mName);
    }
    void visit(PStatLabeled p){
        assert(false, mName);
    }
    void visit(PStatGoto p){
        assert(false, mName);
    }
    void visit(PStatIf p){
        assert(false, mName);
    }
    void visit(PStatFor p){
        assert(false, mName);
    }
    void visit(PStatForeach p){
        assert(false, mName);
    }
    void visit(PStatWhile p){
        assert(false, mName);
    }
    void visit(PStatDo p){
        assert(false, mName);
    }
    void visit(PStatBreak p){
        assert(false, mName);
    }
    void visit(PStatContinue p){
        assert(false, mName);
    }
    void visit(PStatReturn p){
        assert(false, mName);
    }
    void visit(PStatSwitch p){
        assert(false, mName);
    }
    void visit(PStatThrow p){
        assert(false, mName);
    }
    void visit(PStatSynchronized p){
        assert(false, mName);
    }
    void visit(PStatTry p){
        assert(false, mName);
    }
    void visit(PStatCatch p){
        assert(false, mName);
    }
    void visit(PStatFinally p){
        assert(false, mName);
    }
    void visit(PStatAssert p){
        assert(false, mName);
    }
}
class PartTraversVisitor : Visitor {

    alias LinkSeq!(IScope) TScopeList;

    PRootPackage mRoot;
    PPackage     mPackage;
    PModule      mModule;
    PTypeDef     mTypeDef;
    PTypeDef     mModuleTypeDef;
    PCallable   mCallable;
    private TScopeList    mScopeStack;

    public this(){
        mScopeStack = new TScopeList;
    }
    protected IScope getScope(){
        return mScopeStack.head();
    }

    protected TScopeList getScopeList(){
        return cast(TScopeList)mScopeStack.duplicate();
    }

    void pushScope( PTypeInst aTypeInst ){
        if( aTypeInst.mDimensions == 0 ){
            pushScope( aTypeInst.mTypeRef.mResolvedTypeDef);
        }
        else{
            pushScope( gTypeJavaLangJArray );
        }
    }

    void pushScope( IScope p ){
        mScopeStack.prepend( p );
    }
    void popScope(){
        mScopeStack.removeHead();
    }
    bool exceptionThrown = false;
    void goVisitPart(PPart aParent, PPart[] e){
        try{
            foreach (PPart p; e) {
                if( p is null ){
                    Stdout.formatln( "Null Exception @ {}", scopeStackToUtf8 );
                }
                p.mPartParent = aParent;
                p.accept(this);
            }
        } catch( Exception o ){
            if( !exceptionThrown ){
                Stdout.formatln( "Exception @ {}", scopeStackToUtf8 );
                exceptionThrown = true;
            }
            throw o;
        }
    }
    void goVisitPart(PPart aParent, PPart e){
        try{
            if (e) {
                e.mPartParent = aParent;
                e.accept(this);
            }
        } catch( Object o ){
            if( !exceptionThrown ){
                Stdout.formatln( "Exception @ {}", scopeStackToUtf8 );
                exceptionThrown = true;
            }
            throw o;
        }
    }

    char[] scopeStackToUtf8(){
        TScopeList lst = getScopeList();
        char[] res;
        while (lst.size() > 0) {
            IScope    scp = lst.take();
            res = scp.toUtf8() ~ "\n" ~ res;
        }
        return res;
    }

    void visit(PPart p){
    }
    void visit(PPackage p){
        PPackage bak = mPackage;
        mPackage = p;

        goVisitPart( p, p.mModules);
        goVisitPart( p, p.mPackages);

        mPackage = bak;
    }
    void visit(PRootPackage p){

        mRoot = p;
        mPackage = p;

        goVisitPart( p, p.mGlobalTypeDefs);
        goVisitPart( p, p.mModules);
        goVisitPart( p, p.mPackages);
    }
    void visit(PModule p){
        mTypeDef = null;
        mModuleTypeDef = null;
        PModule bak = mModule;
        mModule = p;

        goVisitPart( p, p.mModuleMethods);
        goVisitPart( p, p.mImports);
        goVisitPart( p, p.mTypeDefs);

        mModule = bak;
    }
    void visit(PImport p){
    }
    void visit(PTypeDef p){
                pushScope( p );
                scope(exit) popScope();
    }
    void visit(PInterfaceDef p){
                pushScope( p );
                scope(exit) popScope();

        if( mModuleTypeDef is null ){
            mModuleTypeDef = p;
        }
        PTypeDef bak = mTypeDef;
        mTypeDef = p;

        goVisitPart( p, p.mMethods);
        goVisitPart( p, p.mTypeDefs);

        mTypeDef = bak;
    }
    void visit(PClassDef p){
                pushScope( p );
                scope(exit) popScope();
        if( mModuleTypeDef is null ){
            mModuleTypeDef = p;
        }
        PTypeDef bak = mTypeDef;
        p.mParent = mTypeDef;
        mTypeDef = p;

        goVisitPart( p, p.mMethods);
        goVisitPart( p, p.mTypeDefs);
        goVisitPart( p, p.mFields);
        goVisitPart( p, p.mCtors);
        goVisitPart( p, p.mStaticCtors);
        goVisitPart( p, p.mInstanceInits);

        mTypeDef = bak;
    }
    void visit(PParameterDef p){
        //nothing
    }
    void visit(PVarDef p){
        goVisitPart( p, p.mInitializer);
    }
    void visit(PFieldDef p){
        goVisitPart( p, p.mInitializer);
    }
    void visit(PLocalVarDef p){
        goVisitPart( p, p.mInitializer);
    }
    void visit(PCallable p){
        PCallable bak = mCallable;
        mCallable = p;
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mStatList);
        mCallable = bak;
    }
    void visit(PCtor p){
        PCallable bak = mCallable;
        mCallable = p;
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mParams);
        goVisitPart( p, p.mStatList);
        mCallable = bak;
    }
    void visit(PStaticCtor p){
        PCallable bak = mCallable;
        mCallable = p;
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mStatList);
        mCallable = bak;
    }
    void visit(PInstanceInit p){
        PCallable bak = mCallable;
        mCallable = p;
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mStatList);
        mCallable = bak;
    }
    void visit(PMethodDef p){
        PCallable bak = mCallable;
        mCallable = p;
        pushScope( p );
        scope(exit) popScope();
        goVisitPart( p, p.mParams);
        goVisitPart( p, p.mStatList);
        mCallable = bak;
    }
    void visit(PVarInitializer p){
        // nothing
    }
    void visit(PVarInitExpr p){
        goVisitPart( p, p.mExpr);
    }
    void visit(PVarInitArray p){
        goVisitPart( p, p.mInitializers);
    }
    void visit(PArrayDecl p){
        goVisitPart( p, p.mCount);
    }
    void visit(PExpr p){
        // nothing
    }
    void visit(PExprVarRef p){
        goVisitPart( p, p.mExprReference );
    }
    void visit(PExprFncRef p){
    }
    void visit(PExprTypeInst p){
    }
    void visit(PExprTypecast p){
        goVisitPart( p, p.mExpr);
    }
    void visit(PExprIdent p){
        // nothing
    }
    void visit(PExprDot p){
        goVisitPart( p, p.mLExpr);
        goVisitPart( p, p.mRExpr);
    }
    void visit(PExprMethodCall p){
        goVisitPart( p, p.mTrgExpr);
        goVisitPart( p, p.mArguments);
    }
    void visit(PExprQuestion p){
        goVisitPart( p, p.mCond);
        goVisitPart( p, p.mTCase);
        goVisitPart( p, p.mFCase);
    }
    void visit(PExprInstanceof p){
        //Stdout.formatln( "1" );
        goVisitPart( p, p.mExpr);
        //Stdout.formatln( "2" );
    }
    void visit(PExprBinary p){
        //Stdout.formatln( "1" );
        goVisitPart( p, p.mLExpr);
        //Stdout.formatln( "2" );
        goVisitPart( p, p.mRExpr);
        //Stdout.formatln( "3" );
    }
    void visit(PExprUnary p){
        goVisitPart( p, p.mExpr);
    }
    void visit(PExprNew p){
        goVisitPart( p, p.mArguments);
    }
    void visit(PExprNewArray p){
        goVisitPart( p, p.mArrayDecls);
        goVisitPart( p, p.mInitializer);
    }
    void visit(PExprNewAnon p){
        goVisitPart( p, p.mArguments);
        goVisitPart( p, p.mClassDef);
    }
    void visit(PExprAssign p){
        goVisitPart( p, p.mLExpr);
        goVisitPart( p, p.mRExpr);
    }
    void visit(PExprIndexOp p){
        goVisitPart( p, p.mRef);
        goVisitPart( p, p.mIndex);
    }
    void visit(PExprLiteral p){
        // nothing
    }
    void visit(PStatement p){
                pushScope( p );
                scope(exit) popScope();
        // nothing
    }
    void visit(PStatList p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mStats);
    }
    void visit(PStatLabeled p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mStat);
    }
    void visit(PStatGoto p){
    }
    void visit(PStatIf p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mCond);
        goVisitPart( p, p.mTCase);
        goVisitPart( p, p.mFCase);
    }
    void visit(PStatFor p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mInit_VarDefs);
        goVisitPart( p, p.mInit_Exprs);
        goVisitPart( p, p.mCondition);
        goVisitPart( p, p.mIterator);
        goVisitPart( p, p.mStat);
    }
    void visit(PStatForeach p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mParam);
        goVisitPart( p, p.mRange);
        goVisitPart( p, p.mStat);
    }
    void visit(PStatWhile p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mTodo);
        goVisitPart( p, p.mCond);
    }
    void visit(PStatDo p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mTodo);
        goVisitPart( p, p.mCond);
    }
    void visit(PStatBreak p){
                pushScope( p );
                scope(exit) popScope();
        // nothing
    }
    void visit(PStatContinue p){
                pushScope( p );
                scope(exit) popScope();
        // nothing
    }
    void visit(PStatReturn p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mValue);
    }
    void visit(PStatSwitch p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mSwitch);
        foreach( PCaseGroup cg; p.mCaseGroups ){
            foreach( PExpr ecase; cg.mCases ){
                goVisitPart( p, ecase );
            }
            goVisitPart( p, cg.mTodo );
            pushScope( cg.mTodo ); // push statlist, so enable variable resolving in previous statements
        }
        foreach( PCaseGroup cg; p.mCaseGroups ){
            popScope(); // remove that extra scopes
        }
    }
    void visit(PStatThrow p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mExpr);
    }
    void visit(PStatSynchronized p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mWith);
        goVisitPart( p, p.mWhat);
    }
    void visit(PStatTry p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mTodo);
        goVisitPart( p, p.mHandlers);
        goVisitPart( p, p.mFinally);
    }
    void visit(PStatCatch p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mParam);
        goVisitPart( p, p.mTodo);
    }
    void visit(PStatFinally p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mTodo);
    }
    void visit(PStatAssert p){
                pushScope( p );
                scope(exit) popScope();
        goVisitPart( p, p.mCond);
        goVisitPart( p, p.mMsg);
    }
}


