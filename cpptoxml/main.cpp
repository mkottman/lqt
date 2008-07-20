/*
 * Copyright 2008 Mauro Iazzi <mauro.iazzi@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 */


#include <iostream>
#include <typeinfo>

#include "binder.h"
#include "codemodel.h"
#include "control.h"
#include "parser.h"
#include "preprocessor.h"

#include <QByteArray>
#include <QFile>
#include <QTextCodec>
#include <QTextStream>

#include <QObject>
#include <QDir>

#include <QDebug>

#define ID_STR(i) (QString("_").append(QString::number(i->creationId())))
#define ATTR_STR(n, v) ( QString(" ") + n + QString("=\"") + v + QString("\"") )
#define ATTR_NUM(n, v) ( (QString::number(v)).prepend(" " n "=\"").append("\"") )
#define ATTR_TRUE(n) ( ATTR_NUM(n, 1) )

using namespace std;

class XMLVisitor {
	private:
		bool resolve_types;
		QString current_id;
		QStringList current_context;
		QList<CodeModelItem> current_scope;
		CodeModelItem outer_scope;
	public:
		XMLVisitor(CodeModelItem c, bool r = true):
			resolve_types(r), current_scope(), outer_scope(c) {
				current_scope << c;
			}
		QString XMLTag(CodeModelItem);
		TypeInfo solve(const TypeInfo&, QStringList);
		TypeInfo simplifyType (TypeInfo const &, CodeModelItem __scope);
		QString visit(const TypeInfo&, QStringList);
		QString visit(CodeModelItem);
		/*
		   template <typename T> QString visit(T) {
		   std::cerr << "unimplemented CodeModelItem: " << typeid(T).name() << std::endl;
		   return "";
		   }
		   */
};


TypeInfo XMLVisitor::simplifyType (TypeInfo const &__type, CodeModelItem __scope)
{
    CodeModel *__model = __scope->model ();
    Q_ASSERT (__model != 0);
    TypeInfo t;
    for (int i=0;i<__type.qualifiedName().size();i++) {
	    QStringList qname = t.qualifiedName();
	    qname << __type.qualifiedName().at(i);
	    t.setQualifiedName(qname);
	    //t = this->solve(t, __scope->qualifiedName());
	    QString oldt = t.toString();
	    t = t.resolveType(t, __scope);
	    if (t.toString()!=oldt) qDebug() << oldt << " --> " << t.toString();
    }

    TypeInfo otherType = __type;
    otherType.setQualifiedName(t.qualifiedName());

    return otherType;
}



TypeInfo XMLVisitor::solve(const TypeInfo& t, QStringList scope) {
	(void)scope;
	if (!resolve_types) return t;
	TypeInfo tt(t);
	for (QList<CodeModelItem>::const_iterator i=current_scope.begin();
			i<current_scope.end();
			i++) {
		TypeInfo ttt = tt;
		//qDebug() << tt.toString() << ttt.toString();
		Q_ASSERT(ttt==tt);
		do {
			tt = ttt;
			ttt = ttt.resolveType(tt, *i);
		} while (ttt!=tt);

	}
	return tt;
}

QString XMLVisitor::visit(const TypeInfo& t, QStringList scope) {
	//t = t.resolveType(t, t.scope());

	QString oldt = t.toString();
	TypeInfo tt = solve(t, scope);
	//tt = simplifyType(tt, current_scope.first());
	while (oldt!=tt.toString()) {
		oldt = tt.toString();
		tt = solve(tt, scope);
	}
	//if (oldt!=tt.toString()) qDebug() << oldt << " -> " << tt.toString();

	QString ret(" type_name=\"");
	ret += tt.toString().append("\"");
	ret += " type_base=\"";
	ret += tt.qualifiedName().join("::").append("\"");
	if (tt.isConstant()) ret += ATTR_TRUE("type_constant");
	if (tt.isVolatile()) ret += ATTR_TRUE("type_volatile");
	if (tt.isReference()) ret += ATTR_TRUE("type_reference");
	if (tt.indirections()>0) ret += ATTR_NUM("indirections", tt.indirections());

	QStringList arr = tt.arrayElements();
	QString tmp = arr.join(",");
	if (!tmp.isEmpty()) ret += " array=\"" + tmp + "\"";

	if (tt.isFunctionPointer()) ret += " function_pointer=\"1\"";

	return ret;
}

#define TAG_CASE(s) case _CodeModelItem::Kind_##s: return #s

QString XMLVisitor::XMLTag(CodeModelItem i) {
	switch (i->kind()) {
		TAG_CASE(Scope);
		TAG_CASE(Namespace);
		TAG_CASE(Member);
		TAG_CASE(Function);
		TAG_CASE(Argument);
		TAG_CASE(Class);
		TAG_CASE(Enum);
		TAG_CASE(Enumerator);
		TAG_CASE(File);
		TAG_CASE(FunctionDefinition);
		TAG_CASE(TemplateParameter);
		TAG_CASE(TypeAlias);
		TAG_CASE(Variable);
	}
	return "";
}

QString templateParametersToString (TemplateParameterList list) {
	QString ret;
	foreach(TemplateParameterModelItem p,list) {
		ret = ret + p->name() + ";";
	}
	return ret;
}

QString XMLVisitor::visit(CodeModelItem i) {
	QString ret("");
	ret += XMLTag(i);

	current_id = ID_STR(i) + " => " + XMLTag(i) + " => " + i->qualifiedName().join("::"); // FIXME: this is debug code

	ret += ATTR_STR("id", ID_STR(i));
	ret += ATTR_STR("name", i->name());
	ret += ATTR_STR("scope", i->scope().join("::"));
	ret += ATTR_STR("context", current_context.join("::"));
	// FIXME: is this a dirty hack? yes, it is!
	if (ArgumentModelItem a = model_dynamic_cast<ArgumentModelItem>(i)) {
		//ret += ATTR_STR("fullname", current_context.join("::")+"::"+i->qualifiedName().join("::"));
	} else if (EnumeratorModelItem a = model_dynamic_cast<EnumeratorModelItem>(i)) {
		ret += ATTR_STR("fullname", current_context.join("::")+"::"+i->qualifiedName().join("::"));
	} else {
		ret += ATTR_STR("fullname", i->qualifiedName().join("::"));
	}

	if (ScopeModelItem s = model_dynamic_cast<ScopeModelItem>(i)) {
		ret += " members=\"";
	}
	if (NamespaceModelItem n = model_dynamic_cast<NamespaceModelItem>(i)) {
		foreach(NamespaceModelItem m, n->namespaces())
			ret += ID_STR(m).append(" ");
	}
	if (ScopeModelItem s = model_dynamic_cast<ScopeModelItem>(i)) {
		foreach(ClassModelItem n, s->classes())
			ret += ID_STR(n).append(" ");
		foreach(EnumModelItem n, s->enums())
			ret += ID_STR(n).append(" ");
		foreach(FunctionModelItem n, s->functions())
			ret += ID_STR(n).append(" ");
		foreach(TypeAliasModelItem n, s->typeAliases())
			ret += ID_STR(n).append(" ");
		foreach(VariableModelItem n, s->variables())
			ret += ID_STR(n).append(" ");
	}
	if (ScopeModelItem s = model_dynamic_cast<ScopeModelItem>(i)) {
		ret += "\"";
	}
	if (MemberModelItem m = model_dynamic_cast<MemberModelItem>(i)) {
		if (m->isConstant()) ret += ATTR_TRUE("constant");
		if (m->isVolatile()) ret += ATTR_TRUE("volatile");
		if (m->isStatic()) ret += ATTR_TRUE("static");
		if (m->isAuto()) ret += ATTR_TRUE("auto");
		if (m->isFriend()) ret += ATTR_TRUE("friend");
		if (m->isRegister()) ret += ATTR_TRUE("register");
		if (m->isExtern()) ret += ATTR_TRUE("extern");
		if (m->isMutable()) ret += ATTR_TRUE("mutable");
		QStringList ownerName = m->qualifiedName();
		ownerName.pop_back();
		ret += ATTR_STR("member_of", ownerName.join("::"));
		
		if (ClassModelItem c = model_dynamic_cast<ClassModelItem>(current_scope.last()))
			ret += ATTR_STR("member_of_class", c->qualifiedName().join("::"));

		switch (m->accessPolicy()) {
			case CodeModel::Public:
				ret += ATTR_STR("access", "public");
				break;
			case CodeModel::Private:
				ret += ATTR_STR("access", "private");
				break;
			case CodeModel::Protected:
				ret += ATTR_STR("access", "protected");
				break;
		};

		ret += visit(m->type(), m->scope());
		QString tp = templateParametersToString(m->templateParameters());
		if (tp!=QString()) ret += ATTR_STR("member_template_parameters", tp);
	}
	if (FunctionModelItem f = model_dynamic_cast<FunctionModelItem>(i)) {
		if (f->isVirtual()) ret += ATTR_TRUE("virtual");
		if (f->isInline()) ret += ATTR_TRUE("inline");
		if (f->isExplicit()) ret += ATTR_TRUE("explicit");
		if (f->isAbstract()) ret += ATTR_TRUE("abstract");
		if (f->isVariadics()) ret += ATTR_TRUE("variadics");
		//if (i->name()=="destroyed") qDebug() << CodeModel::Normal << CodeModel::Slot << CodeModel::Signal << m->functionType() << i->qualifiedName();
		switch(f->functionType()) {
			case CodeModel::Normal:
				break;
			case CodeModel::Slot:
				ret += ATTR_TRUE("slot");
				break;
			case CodeModel::Signal:
				ret += ATTR_TRUE("signal");
				break;
		}
	}
	if (ArgumentModelItem a = model_dynamic_cast<ArgumentModelItem>(i)) {
		ret += visit(a->type(), a->scope());
		if (a->defaultValue()) {
			ret += ATTR_TRUE("default");
			ret += ATTR_STR("defaultvalue", a->defaultValueExpression());
		}
	}
	if (ClassModelItem c = model_dynamic_cast<ClassModelItem>(i)) {
		if (c->baseClasses().size()>0) {
			ret += ATTR_STR("bases", c->baseClasses().join(";").append(";"));
		}
		switch(c->classType()) {
			case CodeModel::Class:
				ret += ATTR_STR("class_type", QString("class"));
				break;
			case CodeModel::Struct:
				ret += ATTR_STR("class_type", QString("struct"));
				break;
			case CodeModel::Union:
				ret += ATTR_STR("class_type", QString("union"));
				break;
		}
		QString tp = templateParametersToString(c->templateParameters());
		if (tp!=QString()) ret += ATTR_STR("member_template_parameters", tp);
		// TODO also list propertyDeclarations (maybe in content?)
	}
	if (EnumModelItem e = model_dynamic_cast<EnumModelItem>(i)) {
		switch (e->accessPolicy()) {
			case CodeModel::Public:
				ret += ATTR_STR("access", "public");
				break;
			case CodeModel::Private:
				ret += ATTR_STR("access", "private");
				break;
			case CodeModel::Protected:
				ret += ATTR_STR("access", "protected");
				break;
		};
	}
	if (EnumeratorModelItem e = model_dynamic_cast<EnumeratorModelItem>(i)) {
		ret += e->value().prepend(" value=\"").append("\"");
	}
	if (TypeAliasModelItem t = model_dynamic_cast<TypeAliasModelItem>(i)) {
		ret += visit(t->type(), t->scope());
	}

	ret.replace('&', "&amp;");
	ret.replace('>', "&gt;");
	ret.replace('<', "&lt;");
	ret = "<" + ret + " >\n";

	//
	// content of the entry:
	//  - Arguments of functions
	//  - members of scopes
	//  - enumeration values
	//
	if (NamespaceModelItem n = model_dynamic_cast<NamespaceModelItem>(i)) {
		foreach(NamespaceModelItem m, n->namespaces())
			ret += visit(model_static_cast<CodeModelItem>(m));
	}
	if (i->kind() & _CodeModelItem::Kind_Scope) {
		//qDebug() << ID_STR(i) << i->name() << current_context;
		//CodeModelItem os = current_scope; // save old outer scope
		if (!i->name().isEmpty()) { current_context << i->name(); current_scope << i; }
		foreach(ClassModelItem n, model_dynamic_cast<ScopeModelItem>(i)->classes())
			ret += visit(model_static_cast<CodeModelItem>(n));
		foreach(EnumModelItem n, model_dynamic_cast<ScopeModelItem>(i)->enums())
			ret += visit(model_static_cast<CodeModelItem>(n));
		foreach(FunctionModelItem n, model_dynamic_cast<ScopeModelItem>(i)->functions())
			ret += visit(model_static_cast<CodeModelItem>(n));
		foreach(TypeAliasModelItem n, model_dynamic_cast<ScopeModelItem>(i)->typeAliases())
			ret += visit(model_static_cast<CodeModelItem>(n));
		foreach(VariableModelItem n, model_dynamic_cast<ScopeModelItem>(i)->variables())
			ret += visit(model_static_cast<CodeModelItem>(n));
		if (!i->name().isEmpty()) { current_context.removeLast(); current_scope.pop_back(); }
	}
	if (FunctionModelItem f = model_dynamic_cast<FunctionModelItem>(i)) {
		foreach(ArgumentModelItem a, f->arguments())
			ret += visit(model_static_cast<CodeModelItem>(a));
	}
	if (EnumModelItem e = model_dynamic_cast<EnumModelItem>(i)) {
		QString last = "0";
		foreach(EnumeratorModelItem n, model_dynamic_cast<EnumModelItem>(i)->enumerators()) {
			if (n->value() == QString()) n->setValue(last.append("+1"));
			ret += visit(model_static_cast<CodeModelItem>(n));
			last = n->value();
		}
	}


	ret += "</";
	ret += XMLTag(i);
	ret += ">\n";
	return ret;
}

int main (int argc, char **argv) {
	bool onlyPreprocess = false;
	bool dontResolve = false;
	QString configName;
	QString sourceName;

	QStringList options;
	for (int i=1;i<argc;i++) options << argv[i];
	int i;
	if ((i=options.indexOf("-C"))!=-1) {
		if (options.count() > i+1) {
			configName = QDir::fromNativeSeparators(options.at(i+1));
			options.removeAt(i+1);
		}
		options.removeAt(i);
	}
	if ((i=options.indexOf("-P"))!=-1) {
		onlyPreprocess = true;
		options.removeAt(i);
	}
	if ((i=options.indexOf("-R"))!=-1) {
		dontResolve = true;
		options.removeAt(i);
	}
	if (options.count()>1) return 37;
	sourceName = QDir::fromNativeSeparators(options.at(0));

	QByteArray contents;

	Preprocessor pp;
	QStringList inclist;

	QString qtdir = QDir::fromNativeSeparators(getenv("QT_INCLUDE"));
	if (qtdir.isEmpty()) {
		fprintf(stderr, "Generator requires QT_INCLUDE to be set\n");
		return false;
	}

	QString currentDir = QDir::current().absolutePath();
	QFileInfo sourceInfo(sourceName);
	//QDir::setCurrent(sourceInfo.absolutePath());

	inclist << (sourceInfo.absolutePath());
	inclist << (QDir::convertSeparators(qtdir));
	inclist << (QDir::convertSeparators(qtdir + "/QtXml"));
	inclist << (QDir::convertSeparators(qtdir + "/QtNetwork"));
	inclist << (QDir::convertSeparators(qtdir + "/QtCore"));
	inclist << (QDir::convertSeparators(qtdir + "/QtGui"));
	inclist << (QDir::convertSeparators(qtdir + "/QtOpenGL"));
	//qDebug() << inclist;

	pp.addIncludePaths(inclist);
	pp.processFile(sourceName, configName);
	//qDebug() << pp.macroNames();
	contents = pp.result();
	//qDebug() << contents;
	//QTextStream(stdout) << contents;

	if (onlyPreprocess) {
		QTextStream(stdout) << contents;
	} else {
		Control control;
		Parser p(&control);
		pool __pool;

		TranslationUnitAST *ast = p.parse(contents, contents.size(), &__pool);

		CodeModel model;
		Binder binder(&model, p.location());
		FileModelItem f_model = binder.run(ast);

		XMLVisitor visitor((CodeModelItem)f_model, !dontResolve);
		QTextStream(stdout) << visitor.visit(model_static_cast<CodeModelItem>(f_model));
	}

	return 0;
}


