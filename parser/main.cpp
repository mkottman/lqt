/*
 * Copyright (c) 2007 Mauro Iazzi
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 */

#include <iostream>
#include <typeinfo>

#include "binder.h"
#include "codemodel.h"
#include "control.h"
#include "parser.h"

#include <QByteArray>
#include <QFile>
#include <QTextCodec>
#include <QTextStream>

#include <QObject>

#include <QDebug>

#define ID_STR(i) (QString("_").append(QString::number(i->creationId())))
#define ATTR_STR(n, v) ( (v).prepend(" " n "=\"").append("\"") )
#define ATTR_NUM(n, v) ( (QString::number(v)).prepend(" " n "=\"").append("\"") )
#define ATTR_TRUE(n) ( ATTR_NUM(n, 1) )

using namespace std;

class XMLVisitor {
	public:
		QString XMLTag(CodeModelItem);
		QString visit(TypeInfo);
		QString visit(CodeModelItem);
		template <typename T> QString visit(T) {
			std::cerr << "unimplemented CodeModelItem: " << typeid(T).name() << std::endl;
			return "";
		}
};
QString XMLVisitor::visit(TypeInfo t) {
	/*
	qDebug() << "=====";
	QStringList::const_iterator constIterator;
	for (constIterator = s_list.constBegin(); constIterator != s_list.constEnd(); ++constIterator)
		qDebug() << *constIterator << "::";
	qDebug() << "const " << t.isConstant();
	qDebug() << "volatile " << t.isVolatile();
	qDebug() << "reference " << t.isReference();
	qDebug() << "indir " << t.indirections();
	qDebug() << "fp? " << t.isFunctionPointer();
	//QStringList arrayElements();
	//QList<TypeInfo> arguments();
	qDebug() << t.toString();
	*/
	//if (s_list.size()>1) qDebug() << t.toString() << s_list;
	//if (s_list.join("::")!=t.toString()) qDebug() << s_list.join("::") << t.toString();
	QString ret(" type_name=\"");
	ret += t.toString().append("\"");
  ret += " type_base=\"";
	ret += t.qualifiedName().join("::").append("\"");
	if (t.isConstant()) ret += ATTR_TRUE("type_constant");
	if (t.isVolatile()) ret += ATTR_TRUE("type_volatile");
	if (t.isReference()) ret += ATTR_TRUE("type_reference");
	if (t.indirections()>0) ret += ATTR_NUM("indirections", t.indirections());
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
QString XMLVisitor::visit(CodeModelItem i) {
	QString ret("<");
	ret += XMLTag(i);

	ret += ATTR_STR("id", ID_STR(i));
	ret += ATTR_STR("name", i->name());
	ret += ATTR_STR("context", i->scope().join("::").append("::"));
	ret += ATTR_STR("fullname", i->qualifiedName().join("::"));

	if (i->kind() & _CodeModelItem::Kind_Scope) {
		ret += " members=\"";
	}
	if ((i->kind() & _CodeModelItem::Kind_Namespace ) == _CodeModelItem::Kind_Namespace) {
		foreach(NamespaceModelItem n, model_dynamic_cast<NamespaceModelItem>(i)->namespaces())
			ret += ID_STR(n).append(" ");
	}
	if (i->kind() & _CodeModelItem::Kind_Scope) {
		foreach(ClassModelItem n, model_dynamic_cast<ScopeModelItem>(i)->classes())
			ret += ID_STR(n).append(" ");
		foreach(EnumModelItem n, model_dynamic_cast<ScopeModelItem>(i)->enums())
			ret += ID_STR(n).append(" ");
		foreach(FunctionModelItem n, model_dynamic_cast<ScopeModelItem>(i)->functions())
			ret += ID_STR(n).append(" ");
		foreach(TypeAliasModelItem n, model_dynamic_cast<ScopeModelItem>(i)->typeAliases())
			ret += ID_STR(n).append(" ");
		foreach(VariableModelItem n, model_dynamic_cast<ScopeModelItem>(i)->variables())
			ret += ID_STR(n).append(" ");
	}
	if (i->kind() & _CodeModelItem::Kind_Scope) {
		ret += "\"";
	}
	if (i->kind() & _CodeModelItem::Kind_Member) {
    MemberModelItem m = model_dynamic_cast<MemberModelItem>(i);
		if (m->isConstant()) ret += ATTR_TRUE("constant");
		if (m->isVolatile()) ret += ATTR_TRUE("volatile");
		if (m->isStatic()) ret += ATTR_TRUE("static");
		if (m->isAuto()) ret += ATTR_TRUE("auto");
		if (m->isFriend()) ret += ATTR_TRUE("friend");
		if (m->isRegister()) ret += ATTR_TRUE("register");
		if (m->isExtern()) ret += ATTR_TRUE("extern");
		if (m->isMutable()) ret += ATTR_TRUE("mutable");

		ret += " access=\"";
		switch (m->accessPolicy()) {
			case CodeModel::Public:
				ret += "public";
				break;
			case CodeModel::Private:
				ret += "private";
				break;
			case CodeModel::Protected:
				ret += "protected";
				break;
		};
		ret += "\"";

		ret += visit(m->type());
	}
	if ((i->kind() & _CodeModelItem::Kind_Function) == _CodeModelItem::Kind_Function) {
    FunctionModelItem m = model_dynamic_cast<FunctionModelItem>(i);
		if (m->isVirtual()) ret += ATTR_TRUE("virtual");
		if (m->isInline()) ret += ATTR_TRUE("inline");
		if (m->isExplicit()) ret += ATTR_TRUE("explicit");
		if (m->isAbstract()) ret += ATTR_TRUE("abstract");
		if (m->isVariadics()) ret += ATTR_TRUE("variadics");
		//if (i->name()=="destroyed") qDebug() << CodeModel::Normal << CodeModel::Slot << CodeModel::Signal << m->functionType() << i->qualifiedName();
		switch(m->functionType()) {
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
	if (i->kind() == _CodeModelItem::Kind_Argument) {
		ArgumentModelItem a = model_dynamic_cast<ArgumentModelItem>(i);
		ret += visit(a->type());
		if (a->defaultValue()) {
			ret += ATTR_TRUE("default");
			ret += ATTR_STR("defaultvalue", a->defaultValueExpression());
		}
	}
	if (i->kind() == _CodeModelItem::Kind_Class) {
		ClassModelItem c = model_dynamic_cast<ClassModelItem>(i);
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
		// TODO also list templateParameters (maybe in content?)
		// TODO also list propertyDeclarations (maybe in content?)
	}
	if (i->kind() == _CodeModelItem::Kind_Enum) {
		EnumModelItem e = model_dynamic_cast<EnumModelItem>(i);
		// TODO try to understand the meaning of the access policy of enums
	}
	if (i->kind() == _CodeModelItem::Kind_Enumerator) {
		EnumeratorModelItem e = model_dynamic_cast<EnumeratorModelItem>(i);
		ret += e->value().prepend(" value=\"").append("\"");
	}
	if (i->kind() == _CodeModelItem::Kind_TypeAlias) {
		TypeAliasModelItem a = model_dynamic_cast<TypeAliasModelItem>(i);
		ret += visit(a->type());
	}

	ret += " >\n";

	//
	// content of the entry:
	//  - Arguments of functions
	//  - members of scopes
	//  - enumeration values
	//
	if ((i->kind() & _CodeModelItem::Kind_Namespace ) == _CodeModelItem::Kind_Namespace) {
		foreach(NamespaceModelItem n, model_dynamic_cast<NamespaceModelItem>(i)->namespaces())
			ret += visit(model_static_cast<CodeModelItem>(n));
	}
	if (i->kind() & _CodeModelItem::Kind_Scope) {
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
	}
	if ((i->kind() & _CodeModelItem::Kind_Function) == _CodeModelItem::Kind_Function) {
		foreach(ArgumentModelItem n, model_dynamic_cast<FunctionModelItem>(i)->arguments())
			ret += visit(model_static_cast<CodeModelItem>(n));
	}
	if (i->kind() == _CodeModelItem::Kind_Enum) {
		QString last = "0";
		EnumModelItem e = model_dynamic_cast<EnumModelItem>(i);
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
/*
template<>
QString XMLVisitor::visit<CodeModelItem>(CodeModelItem i) {
	QString ret;
	ret += "unknown CodeModelItem"; ret += i->name();
	QStringList s_list = i->qualifiedName();
	QStringList::const_iterator constIterator;
	for (constIterator = s_list.constBegin(); constIterator != s_list.constEnd(); ++constIterator) ret += *constIterator;
	return ret;
}
template<>
QString XMLVisitor::visit<ClassModelItem>(ClassModelItem i) {
	QString buf("<");
	switch (i->classType()) {
		case CodeModel::Struct: buf += "Struct"; break;
		case CodeModel::Class: buf += "Class"; break;
		case CodeModel::Union: buf += "Union"; break;
	}
	buf.append(" id=\"").append(ID_STR(i)).append("\"");
	buf += QString(" name=\"").append(i->name().isEmpty()?QString("::"):i->name()).append("\"");
	buf += " members=\"";
	foreach (ClassModelItem m, i->classes()) buf += ID_STR(m).append(" ");
	foreach (EnumModelItem m, i->enums()) buf += ID_STR(m).append(" ");
	foreach (FunctionModelItem m, i->functions()) buf += ID_STR(m).append(" ");
	foreach (TypeAliasModelItem m, i->typeAliases()) buf += ID_STR(m).append(" ");
	foreach (VariableModelItem m, i->variables()) buf += ID_STR(m).append(" ");
	buf.append("\" />\n");

	foreach (ClassModelItem m, i->classes()) visit(m);
	foreach (EnumModelItem m, i->enums()) visit(m);
	foreach (FunctionModelItem m, i->functions()) visit(m);
	foreach (TypeAliasModelItem m, i->typeAliases()) visit(m);
	foreach (VariableModelItem m, i->variables()) visit(m);
	return buf;
}
template<>
QString XMLVisitor::visit<NamespaceModelItem>(NamespaceModelItem n) {
	QString buf("<Namespace");
	buf.append(" id=\"").append(ID_STR(n)).append("\"");
	buf += QString(" name=\"").append(n->name().isEmpty()?QString("::"):n->name()).append("\"");
	buf += " members=\"";
	foreach (NamespaceModelItem m, n->namespaces()) buf += ID_STR(m).append(" ");
	foreach (ClassModelItem m, n->classes()) buf += ID_STR(m).append(" ");
	foreach (EnumModelItem m, n->enums()) buf += ID_STR(m).append(" ");
	foreach (FunctionModelItem m, n->functions()) buf += ID_STR(m).append(" ");
	foreach (TypeAliasModelItem m, n->typeAliases()) buf += ID_STR(m).append(" ");
	foreach (VariableModelItem m, n->variables()) buf += ID_STR(m).append(" ");
	buf.append("\" />\n");

	foreach (NamespaceModelItem m, n->namespaces()) buf += visit(m);
	foreach (ClassModelItem m, n->classes()) buf += visit(m);
	foreach (EnumModelItem m, n->enums()) buf += visit(m);
	foreach (FunctionModelItem m, n->functions()) buf += visit(m);
	foreach (TypeAliasModelItem m, n->typeAliases()) buf += visit(m);
	foreach (VariableModelItem m, n->variables()) buf += visit(m);
	return buf;
}
*/
int main (int argc, char **argv) {
	if (argc<2) {}

	QFile file(argv[1]);

	if (!file.open(QFile::ReadOnly))
		return false;

	QTextStream stream(&file);
	stream.setCodec(QTextCodec::codecForName("UTF-8"));
	QByteArray contents = stream.readAll().toUtf8();
	file.close();


	Control control;
	Parser p(&control);
	pool __pool;

	TranslationUnitAST *ast = p.parse(contents, contents.size(), &__pool);

	CodeModel model;
	Binder binder(&model, p.location());
	FileModelItem f_model = binder.run(ast);

	XMLVisitor visitor;
	QTextStream(stdout) << visitor.visit(model_static_cast<CodeModelItem>(f_model));

	return 0;
}


