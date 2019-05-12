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
module tioport.dmodwriter;

import tioport.tioport;
import tioport.parts;
import tioport.partvisitor;
import tioport.utils;

import tango.text.Util : trim, replace, locatePattern;
import tango.text.convert.Integer;
//import tango.text.stream.LineIterator;
import tango.io.Stdout;
//import tango.io.Print;
import tango.io.model.IFile; // FileConst;
import tango.io.Console;
import tango.io.model.IConduit; // io.Buffer;
// import tango.io.FileConduit;
import tango.core.Array;

//TioPortMixin module
//TioPortMixin Control
//TioPortMixin Control.ListenerImpl
const char[] mixinSeperator = "//TioPortMixin ";
const char[] mixinEnd = "// end of TioPortMixin ";
const char[] dmoduleExtension = ".d";

class MixinReader {
    string it;
    //LineIterator!(char) it;
    char[] id;
    char[] nextline;
    char[] filename;

    public this( char[] filename ){
        this.filename = filename;
        //FIXME it = new LineIterator!(char)();
        auto fp = new FilePath( filename );
        if( fp.exists ){
            auto fc = new FileConduit( filename );
            //it.set( fc );
            //Stdout.formatln( "X {} found", filename );
            get();
        }
    }

    bool matches( char[] pattern ){
        return id == pattern;
    }

    char[] get(){
        char[] result = nextline;
        nextline = null;
        if(! it.getBuffer.readable ){
            it.getBuffer.fill;
        }
        if( it.getBuffer.readable ){
            nextline = it.next().dup;
            //Stdout.formatln( "L ({})", nextline );
            if( nextline && locatePattern( nextline, mixinSeperator ) == 0 ){
                id = .trim( nextline[ mixinSeperator.length .. $ ] ).dup;
            }
        }
        else{
            id = null;
        }
        return result;
    }

    void checkComplete(){
        IBuffer b = it.getBuffer;
        if( b is null ){
            return;
        }
        b.fill;
        if( nextline || b.readable ){
            throw new Exception( Layouter( "MixinReader not empty for file {}", filename ));
        }
    }

}

private MixinReader mixinreader;

void writeDModule(char[] aRootPath, char[] aMixinTree, PModule aModule ){
    if( aModule.mIsNowrite ){
        return;
    }
    char[]        packagePath;
    PPackage      cur   = aModule.mPackage;
    bool          first = true;
    while (cur !is null) {
        if (first ) {
            packagePath = cur.mName;
        }
        else {
            if( cur.mName.length ){
                packagePath = cur.mName ~FileConst.PathSeparatorString ~packagePath;
            }
        }
        cur   = cur.mParent;
        first = false;
    }
    char[]        filename;
    char[]        mixinname;
    if( aRootPath.length > 0 ){
        filename = aRootPath ~FileConst.PathSeparatorString;
    }
    if( aMixinTree.length > 0 ){
        mixinname = aMixinTree ~FileConst.PathSeparatorString;
    }
    if( packagePath.length > 0 ){
        filename ~= packagePath ~FileConst.PathSeparatorString;
        mixinname ~= packagePath ~FileConst.PathSeparatorString;

        char[] dir =(new FilePath( filename )).parent();
        //Stdout.formatln( "*** fn {0}    {1}", dir, filename );
        createFolders( dir );
    }

    filename  ~=aModule.mName ~dmoduleExtension;
    mixinname ~=aModule.mName ~dmoduleExtension;

    mixinreader = new MixinReader( mixinname );
    //Stdout.formatln( "*** fn {0}", filename );


    FileConduit   file = new FileConduit(filename, FileConduit.ReadWriteCreate);
    file.truncate();
    // FIXME DModuleWriter w          = new DModuleWriter(new Print!(char)(Layouter,new Buffer(file)));
    PartWriter    partWriter = new PartWriter(w);
    partWriter.mIsStub = aModule.mIsStub;

    w.write( aModule.mHeaderText );
    w.formatln("module {0};", aModule.getFqn());
    w.nl();
    foreach (PModule imp; aModule.mImportedModules) {
        w.formatln("import {0};", imp.getFqn());
    }
    w.nl();
    if( mixinreader.matches( "module" )){
        while( mixinreader.matches( "module" )){
            w.writeln( mixinreader.get() );
            //w.nl();
        }
        w.writeln( mixinEnd );
        w.nl();
    }
    foreach (PMethodDef mth; aModule.mModuleMethods) {
        partWriter.writePart(mth);
    }
    foreach (PTypeDef td; aModule.mTypeDefs) {
        partWriter.writePart(td);
    }
    mixinreader.checkComplete;
    w.flush();
}


private {
    class PartWriter : Visitor {
        bool          mIsStub;
        void visit(PPart p){
            assert(false);
        }
        void visit(PPackage p){
            assert(false);
        }
        void visit(PRootPackage p){
            assert(false);
        }
        void visit(PModule p){
            assert(false);
        }
        void visit(PImport p){
            assert(false);
        }
        void visit(PTypeDef p){
            assert(false);
        }
        void visit(PCallable p){
            assert(false);
        }
        void visit(PVarInitializer p){
            assert(false);
        }
        void visit(PStatement p){
            assert(false);
        }
        void visit(PStatGoto p){
            w.write("goto ");
            w.write(p.mName);
            w.write(";");
            w.nl();
        }
        void visit(PStatLabeled p){
            w.writeWithoutIndent(p.mName);
            w.write(":");
            if( p.mStat is null ){
                w.write(";");
            }

            w.nl();

            if( p.mStat !is null ){
                writePart(p.mStat);
            }
        }
        void visit(PStatWhile p){
            w.write("while ( ");
            avoidParenthesis({
                    writePart(p.mCond);
                });
            w.write(")");
            writeStatementEnclosed(p.mTodo);
        }
        void visit(PStatDo p){
            w.write("do ");
            writeStatementEnclosed(p.mTodo);
            w.write("while(");
            avoidParenthesis({
                    writePart(p.mCond);
                });
            w.write(")");
        }
        void visit(PStatThrow p){
            w.write("throw ");
            avoidParenthesis({
                    writePart(p.mExpr);
                });
            w.write(";");
            w.nl();
        }
        void visit(PStatSynchronized p){
            w.write("synchronized ( ");
            writePart(p.mWith);
            w.write(")");
            writePart(p.mWhat);
        }
        void visit(PStatAssert p){
            w.write("assert( ");
            writePart(p.mCond);
            if (p.mMsg) {
                w.write(", ");
                writePart(p.mMsg);
            }
            w.write(");");
            w.nl();
        }
        DModuleWriter w;
        this(DModuleWriter w){
            this.w = w;
        }
        void writePart(PPart p){
            if (p is null) {
                return;
            }
            p.accept(this);
        }

        void closeExpr(PExpr p){
            if (p.mAsStatement) {
                w.write(";");
                w.nl();
            }
        }
        void visit(PExpr p){
            w.write(p.mResolvedTypeInst.mTypeRef.getString());
        }
        void visit(PExprVarRef p){
            if( p.mGetAddress ){
                w.write("&");
            }
            if( p.mParameterDef.mName != "this" ){
                if( p.mFromTypeDef !is null ){
                    assert( p.mExprReference is null );
                    w.write( p.mFromTypeDef.getFqn);
                    w.write(".");
                }
                else if( p.mExprReference !is null ){
                    assert( p.mFromTypeDef is null );
                    allowParenthesis({
                        writePart( p.mExprReference );
                    });
                    w.write(".");
                }
            }
            w.write(p.mParameterDef.mName);
            if( p.mOffsetOf ){
                w.write(".offsetof");
            }
        }
        void visit(PExprFncRef p){
            w.write("&");
            if( p.mMethodDef.mModifiers.mStatic && !p.mNoFqn ){
                PInterfaceDef id = cast( PInterfaceDef )p.mMethodDef.mPartParent;
                assert( id !is null );
                w.write( id.getFqn);
                w.write(".");
            }
            w.write(p.mMethodDef.mName);
        }
        void visit(PExprTypeInst p){
            w.write( .trim( p.mResolvedTypeInst.getString() ));
            if( p.mTypeArguments.length > 0 ){
                w.write("!(");
                bool      first = true;
                foreach (PExpr e; p.mTypeArguments) {
                    w.write(first ? " " : ", ");
                    writePart(e);
                    first = false;
                }
                w.write(")");
            }
        }
        void visit(PExprNew p){
            makeParenthesis({
                    w.write("new ");
                    w.write(p.mTypeRef.getString());
                    if( p.mArguments.length > 0 ){
                        w.write("(");
                        bool first = true;
                        foreach (PExpr e; p.mArguments) {
                            w.write(first ? " " : ", ");
                            writePart(e);
                            first = false;
                        }
                        w.write(")");
                    }
                });
            closeExpr(p);
        }
        void visit(PArrayDecl p){
            writePart(p.mCount);
        }
        void visit(PExprNewArray p){
            makeParenthesis({
                    if (p.mInitializer !is null && p.mInitializer.mInitializers.length > 0) {
                        writePart(p.mInitializer);
                    }
                    else {
                        w.write("new ");
                        w.write(p.mTypeRef.getString());

                        foreach (PArrayDecl pd; p.mArrayDecls) {
                            w.write("[]");
                        }
                        w.write("(");
                        bool first = true;
                        foreach_reverse (PArrayDecl pd; p.mArrayDecls) {
                            if (pd.mCount !is null) {
                                w.write(first ? " " : ", ");
                                writePart(pd);
                                first = false;
                            }
                        }
                        w.write(first ? "0 )" : " )");
                    }
                });
            closeExpr(p);
        }
        void visit(PExprNewAnon p){
            w.write("new class");
            w.write("(");
            bool first = true;
            foreach (PExpr e; p.mArguments) {
                w.write(first ? " " : ", ");
                writePart(e);
                first = false;
            }
            w.write(")");

            if (p.mClassDef.mSuperClass !is null || p.mClassDef.mSuperIfaces.length > 0) {
                first = true;
                void writeItem(PTypeRef tr){
                    w.write(first ? " " : ", ");
                    w.write(tr.mResolvedTypeDef.getFqn());
                    first = false;
                }
                if (p.mClassDef.mSuperClass !is null) {
                    writeItem(p.mClassDef.mSuperClass);
                }
                foreach (PTypeRef tr; p.mClassDef.mSuperIfaces) {
                    writeItem(tr);
                }
                w.write(" ");
            }

            writeObjectBlock(p.mClassDef);
            closeExpr(p);
        }
        void visit(PExprTypecast p){
            makeParenthesis({
                    w.format(" cast({0})", p.mTypeInst.getString());
                    writePart(p.mExpr);
                });
            closeExpr(p);
        }
        void visit(PExprMethodCall p){

            PMethodDef mth = cast(PMethodDef)p.mResolvedCallable;
            if (p.mTrgExpr !is null) {
                PExprVarRef vr = cast(PExprVarRef)p.mTrgExpr;
                if( vr !is null &&  vr.mIsSuperRef ){
                    w.write("super");
                }
                else{
                allowParenthesis({
                        writePart(p.mTrgExpr);
                    });
                }
                w.write(".");
            }
            else if ( mth !is null && mth.mModuleFunc !is null ){
                w.write( mth.mModuleFunc.getFqn() );
                w.write(".");
            }

            bool forceCallParens = false;
            if (mth !is null && mth.mName !is null) {
                w.write(mth.mName);
            }
            else {
                // ctor calls. the name is dependent from the calling context.
                // renaming will not happen, so simply take the value from the caller.
                w.write(p.mName);
                forceCallParens = true;
            }

            if( p.mTypeArguments.length > 0 ){
                w.write("!(");
                bool      first = true;
                foreach (PExpr e; p.mTypeArguments) {
                    w.write(first ? " " : ", ");
                    writePart(e);
                    first = false;
                }
                w.write(")");
            }

            if( p.mArguments.length > 0 || forceCallParens ){
                w.write("(");
                bool      first = true;
                foreach (PExpr e; p.mArguments) {
                    w.write(first ? " " : ", ");
                    writePart(e);
                    first = false;
                }
                w.write(")");
            }
            closeExpr(p);
        }
        void visit(PExprIdent p){
            // all idents should be converted to PExprVarRef or PExprTypeInst
                w.write("×");
                w.write(p.mName);
                w.write("×");
            //assert(false, p.mName);
        }
        void visit(PExprDot p){
            allowParenthesis({
                    writePart(p.mLExpr);
                });
            w.write(".");
            allowParenthesis({
                    writePart(p.mRExpr);
                });
            closeExpr(p);
        }
        void visit(PExprQuestion p){
            makeParenthesis({
                    writePart(p.mCond);
                    w.write(" ? ");
                    writePart(p.mTCase);
                    w.write(" : ");
                    writePart(p.mFCase);
                });
            closeExpr(p);
        }
        void visit(PExprInstanceof p){
            makeParenthesis({
                    w.write(" (cast( ");
                    w.write(p.mTypeInst.getString());
                    w.write(" ) ");
                    writePart(p.mExpr);
                    w.write(" ) !is null ");
                });
            closeExpr(p);
        }
        void visit(PExprBinary p){
            makeParenthesis({
                    writePart(p.mLExpr);
                    w.format(" {0} ", p.mOp);
                    writePart(p.mRExpr);
                });
            closeExpr(p);
        }
        void visit(PExprUnary p){
            makeParenthesis({
                    if (p.mPost) {
                        writePart(p.mExpr);
                        w.format(p.mOp);
                    }
                    else {
                        w.format(p.mOp);
                        writePart(p.mExpr);
                    }
                });
            closeExpr(p);
        }
        void visit(PExprAssign p){
            makeParenthesis({
                    writePart(p.mLExpr);
                    w.format(" {0} ", p.mOp);
                    writePart(p.mRExpr);
                });
            closeExpr(p);
        }
        void visit(PExprIndexOp p){
            writePart(p.mRef);
            w.format(" [ ");
            writePart(p.mIndex);
            w.format(" ] ");
            closeExpr(p);
        }
        void visit(PExprLiteral p){
            w.write(p.mText);
            closeExpr(p);
        }
        void visit(PStatSwitch p){
            w.write("switch (");
            avoidParenthesis({
                    writePart(p.mSwitch);
                });
            w.write(" ) ");
            w.enclose({
                    foreach (PCaseGroup cg; p.mCaseGroups) {
                        foreach (PExpr ecase; cg.mCases) {
                            w.write("case ");
                            avoidParenthesis({
                                    writePart(ecase);
                                });
                            w.write(":");
                            w.nl();
                        }
                        if (cg.mIsDefault) {
                            w.write("default:");
                            w.nl();
                        }
                        if (cg.mTodo !is null) {
                            writePart(cg.mTodo);
                        }
                    }
                });
        }
        void visit(PStatContinue p){
            if (p.mName) {
                w.write("continue ");
                w.write(p.mName);
                w.write(";");
                w.nl();
            }
            else {
                w.write("continue;");
                w.nl();
            }
        }
        void visit(PStatBreak p){
            if (p.mName) {
                w.write("break ");
                w.write(p.mName);
                w.write(";");
                w.nl();
            }
            else {
                w.write("break;");
                w.nl();
            }
        }
        void writeStatementEnclosed(PStatement aStat){
            if (cast(PExpr)aStat) {
                w.enclose({
                        writePart(aStat);
                    });
            }
            else {
                writePart(aStat);
            }
        }
        void visit(PStatIf p){
            w.write("if (");
            avoidParenthesis({
                    writePart(p.mCond);
                });
            w.write(" ) ");
            avoidParenthesis({
                    writeStatementEnclosed(p.mTCase);
                });
            if (p.mFCase !is null) {
                w.write("else ");
                avoidParenthesis({
                        writeStatementEnclosed(p.mFCase);
                    });
            }
        }
        bool          paramWithoutType = false;
        void visit(PStatFor p){
            w.write("for (");
            bool first = true;
            avoidParenthesis({
                    foreach (PExpr e; p.mInit_Exprs) {
                        w.write(first ? " " : ", ");
                        writePart(e);
                        first = false;
                    }
                    foreach (PVarDef e; p.mInit_VarDefs) {
                        w.write(first ? " " : ", ");
                        writePart(e);
                        paramWithoutType = true;
                        first = false;
                    }
                    paramWithoutType = false;
                });
            w.write(first ? ";" : " ;");
            avoidParenthesis({
                    writePart(p.mCondition);
                });
            w.write(";");
            avoidParenthesis({
                    first = true;
                    foreach (PExpr e; p.mIterator) {
                        w.write(first ? " " : ", ");
                        writePart(e);
                        first = false;
                    }
                });
            w.write(first ? ") " : " ) ");
            writeStatementEnclosed(p.mStat);
        }
        void visit(PStatForeach p){
            w.write("foreach ( ");
            avoidParenthesis({
                    writePart(p.mParam);
                });
            w.write("; ");
            avoidParenthesis({
                    writePart(p.mRange);
                });
            w.write(" )");
            writeStatementEnclosed(p.mStat);
        }
        void visit(PStatTry p){
            w.write("try ");
            writeStatementEnclosed(p.mTodo);
            foreach (PStatCatch c; p.mHandlers) {
                writePart(c);
            }
            if (PStatFinally f = p.mFinally) {
                writePart(f);
            }
        }
        void visit(PStatCatch p){
            w.write("catch ( ");
            writePart(p.mParam);
            w.write(" ) ");
            writeStatementEnclosed(p.mTodo);
        }
        void visit(PStatFinally p){
            assert( false, "finally shall be replaced" );
            w.write("finally ");
            w.enclose({
                    w.write("()");
                    w.enclose({
                            writeStatementEnclosed(p.mTodo);
                        });
                    w.write("();");
                    w.nl();
                });
        }
        void visit(PVarInitExpr p){
            writePart(p.mExpr);
        }
        void visit(PStatReturn p){
            w.write("return ");
            writePart(p.mValue);
            w.write(";");
            w.nl();
        }
        void visit(PVarInitArray p){
            if( p.mInitializers.length > 0 ){
                w.write("([");
                bool first = true;
                foreach (PVarInitializer v; p.mInitializers) {
                    w.write(first ? " " : ", ");
                    writePart(v);
                    first = false;
                }
                w.write(" ])" );
            }
            w.write("[]");
        }
        void visit(PCtor p){
            w.write(p.mModifiers.getString());
            w.write("this (");
            bool first = true;
            foreach (PParameterDef pd; p.mParams) {
                w.write(first ? " " : ", ");
                visit( pd );
                //w.write(pd.mModifiers.getString());
                //w.write(pd.mTypeInst.getString());
                //w.write(pd.mName);
                first = false;
            }
            w.write(first ? ")" : " )");
            writePart(p.mStatList);
            w.nl();
        }
        void visit(PStaticCtor p){
            w.write("static this()");
            if (p.mStatList && !mIsStub) {
                writePart(p.mStatList);
            }
            else {
                w.write(";");
            }
            w.nl();
        }
        void visit(PInstanceInit p){
            //FIXME wenn alle Refactoring aktiv, das assert aktivieren
            // in D there is no instance init feature
            // assert( false );
        }
        void visit(PMethodDef p){

            foreach( char[] comment; p.mComments ){
                w.write("// ");
                w.write(comment);
                w.nl();
            }
            w.write(p.mModifiers.getString());
            w.write(p.mReturnType.getString());

            // probably write another name for the method,
            // this will make it possible to exchange it with a
            // method decl from the mixin
            char[] name = p.mName;
            if( name in p.mModule.mExchangeFuncs ){
                name = p.mModule.mExchangeFuncs[ name ];
            }
            w.write(name);

            w.write("(");
            bool first = true;
            foreach (PParameterDef pd; p.mParams) {
                w.write(first ? " " : ", ");
                visit( pd );
                //w.write(pd.mModifiers.getString());
                //w.write(pd.mTypeInst.getString());
                //w.write(pd.mName);
                first = false;
            }
            w.write(first ? ")" : " )");

            if (p.mStatList !is null) {
                writePart(p.mStatList);
            }
            else {
                w.write(";");
            }
            w.nl();
        }
        void visit(PStatList p){
            if (p.mWithoutScope) {
                w.indentOnly({
                        foreach (PStatement stat; p.mStats) {
                            avoidParenthesis({
                                    writePart(stat);
                                });
                        }
                    });
            }
            else {
                w.enclose({
                        foreach (PStatement stat; p.mStats) {
                            avoidParenthesis({
                                    writePart(stat);
                                });
                        }
                    });
            }
        }
        void visit(PParameterDef p){
            if (!paramWithoutType) {
                w.write(p.mModifiers.getString());
                w.write(p.mTypeInst.getString());
            }
            w.write(p.mName);
            if( p.mIsVariableLength ){
                w.write( " ... " );
            }
        }
        void visit(PVarDef p){
            visit(cast(PParameterDef)p);
            if (p.mInitializer !is null) {
                w.write(" = ");
                writePart(p.mInitializer);
            }
            if (!p.mInExpression) {
                w.write(";");
                w.nl();
            }
        }
        void visit(PFieldDef p){
            visit(cast(PVarDef)p);
        }
        void visit(PLocalVarDef p){
            visit(cast(PVarDef)p);
        }


        void writeObjectBlock(PClassDef p){

            w.enclose({
                    char[] fqn = p.getFqn()[ p.mModule.getFqn().length+1 .. $ ];
                    if( mixinreader.matches( fqn )){
                        w.nl();
                        while( mixinreader.matches( fqn )){
                            w.writeln( mixinreader.get() );
                            //w.nl();
                        }
                        w.writeln( mixinEnd );
                        w.nl();
                    }
                    w.nl();
                    foreach (AliasFunction al; p.mAliases) {
                        w.format("alias {0}.{1} {1};", al.mClassDef.getFqn(), al.mName);
                        w.nl();
                    }
                    w.nl();
                    foreach (PFieldDef v; p.mFields) {
                        writePart(v);
                    }
                    foreach (PTypeDef v; p.mTypeDefs) {
                        writePart(v);
                    }
                    foreach (PCallable v; cast(PCallable[])p.mStaticCtors) {
                        writePart(v);
                    }
                    foreach (PCallable v; cast(PCallable[])p.mInstanceInits) {
                        writePart(v);
                    }
                    foreach (PCallable v; cast(PCallable[])p.mCtors) {
                        writePart(v);
                    }
                    foreach (PCallable v; cast(PCallable[])p.mMethods) {
                        writePart(v);
                    }
                    w.nl();

                });
        }
        void visit(PClassDef p){
            w.write(p.mModifiers.getString());
            w.format("class {0} ", p.mName);
            if (p.mSuperClass !is null || p.mSuperIfaces.length > 0) {
                bool first = true;
                void writeItem(PTypeRef tr){
                    w.write(first ? ": " : ", ");
                    w.write(tr.mResolvedTypeDef.getFqn());
                    first = false;
                }
                if (p.mSuperClass !is null) {
                    writeItem(p.mSuperClass);
                }
                foreach (PTypeRef tr; p.mSuperIfaces) {
                    writeItem(tr);
                }
                w.write(" ");
            }
            writeObjectBlock(p);
            w.nl();
            w.nl();
        }
        void visit(PInterfaceDef p){

            w.write(p.mModifiers.getString());
            w.format("interface {0} ", p.mName);
            if (p.mSuperIfaces.length > 0) {
                bool first = true;
                foreach (PTypeRef tr; p.mSuperIfaces) {
                    w.write(first ? ": " : ", ");
                    w.write(tr.getString());
                    first = false;
                }
                w.write(" ");
            }
            w.enclose({
                    char[] fqn = p.getFqn()[ p.mModule.getFqn().length+1 .. $ ];
                    if( mixinreader.matches( fqn )){
                        w.nl();
                        while( mixinreader.matches( fqn )){
                            w.writeln( mixinreader.get() );
                            //w.nl();
                        }
                        w.writeln( mixinEnd );
                        w.nl();
                    }
                    w.nl();
                    foreach (PTypeDef v; p.mTypeDefs) {
                        writePart(v);
                    }
                    foreach (PCallable v; cast(PCallable[])p.mMethods) {
                        writePart(v);
                    }
                    w.nl();
                });
            w.nl();
            w.nl();
        }
        private bool  mAvoidParenthesis;
        private void allowParenthesis(void delegate() aDg){
            bool old = mAvoidParenthesis;

            mAvoidParenthesis = false;
            aDg();
            mAvoidParenthesis = old;
        }
        private void avoidParenthesis(void delegate() aDg){
            bool old = mAvoidParenthesis;

            mAvoidParenthesis = true;
            aDg();
            mAvoidParenthesis = old;
        }
        private void makeParenthesis(void delegate() aDg){
            bool p = !mAvoidParenthesis;

            mAvoidParenthesis = false;
            if (p) {
                w.write("(");
            }
            aDg();
            if (p) {
                w.write(")");
            }
        }
    }


    class DModuleWriter {
        //FIXME Print!(char) w;
	string w;
        int           indent = 0;
        bool          indentWait;

        char[]        getIndentSpaces(int aCount){
            char[] res;
            while (aCount--) {
                res ~= " ";
            }
            return(res);
        }
        char[] getIndention(){
            return(getIndentSpaces(indent * 4));
        }

        this(string aWriter){
            indentWait = false;
            w          = aWriter;
        }
        //FIXME
	/+
	this(Print!(char) aWriter){
            indentWait = false;
            w          = aWriter;
        }
	+/
        void formatln(char[] aFormat, ...){
            checkIndent();
            write(Layouter(_arguments, _argptr, aFormat));
            nl();
        }
        void format(char[] aFormat, ...){
            checkIndent();
            write(Layouter(_arguments, _argptr, aFormat));
        }
        void writeWithoutIndent(char[] aStr){
            w(aStr);
        }
        void write(char[] aStr){
            checkIndent();
            w(aStr);
        }
        void writeln(char[] aStr){
            checkIndent();
            w(aStr);
            nl();
        }
        void flush(){
            w.flush();
        }
        void nl(){
            w.newline;
            indentWait = true;
        }
        private void checkIndent(){
            if (indentWait) {
                w(getIndention());
                indentWait = false;
            }
        }

        void indentOnly(void delegate() aDg){
            nl();
            indent++;
            aDg();
            indent--;
            nl();
        }
        void enclose(void delegate() aDg){
            write("{");
            nl();
            indent++;
            aDg();
            indent--;
            write("}");
            nl();
        }
    }
}


