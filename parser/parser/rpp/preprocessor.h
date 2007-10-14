/****************************************************************************
**
** Copyright (C) 1992-2007 Trolltech ASA. All rights reserved.
**
** This file is part of Qt Jambi.
**
** ** This file may be used under the terms of the GNU General Public
** License version 2.0 as published by the Free Software Foundation
** and appearing in the file LICENSE.GPL included in the packaging of
** this file.  Please review the following information to ensure GNU
** General Public Licensing requirements will be met:
** http://www.trolltech.com/products/qt/opensource.html
**
** If you are unsure which license is appropriate for your use, please
** review the following information:
** http://www.trolltech.com/products/qt/licensing.html or contact the
** sales department at sales@trolltech.com.

**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
****************************************************************************/

/*
  Copyright 2005 Harald Fernengel <harry@kdevelop.org>

  Permission to use, copy, modify, distribute, and sell this software and its
  documentation for any purpose is hereby granted without fee, provided that
  the above copyright notice appear in all copies and that both that
  copyright notice and this permission notice appear in supporting
  documentation.

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  KDEVELOP TEAM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
  AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#ifndef PREPROCESSOR_H
#define PREPROCESSOR_H

#include <QtCore/qglobal.h>
#include <QtCore/qstring.h>
#include <QtCore/qstringlist.h>

class QByteArray;
class PreprocessorPrivate;

class Preprocessor
{
public:
    Preprocessor();
    ~Preprocessor();

    void processFile(const QString &fileName);
    void processString(const QByteArray &str);

    void addIncludePaths(const QStringList &includePaths);

    QByteArray result() const;

    QStringList macroNames() const;

    struct MacroItem
    {
        QString name;
        QStringList parameters;
        QString definition;
        bool isFunctionLike;
#ifdef PP_WITH_MACRO_POSITION
        QString fileName;
#endif
    };
    QList<MacroItem> macros() const;

private:
    Q_DISABLE_COPY(Preprocessor)
    PreprocessorPrivate *d;
};

#endif
