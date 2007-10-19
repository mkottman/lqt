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

/* This file is part of KDevelop
    Copyright (C) 2006 Roberto Raggi <roberto@kdevelop.org>
    Copyright (C) 2006 Trolltech AS

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License version 2 as published by the Free Software Foundation.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public License
   along with this library; see the file COPYING.LIB.  If not, write to
   the Free Software Foundation, Inc., 51 Franklin Steet, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/
#ifndef CODEMODEL_POINTER_H
#define CODEMODEL_POINTER_H

#include <QtCore/QSharedData>

template <class T> class CodeModelPointer
{
public:
    typedef T Type;

    inline T &operator*() { return *d; }
    inline const T &operator*() const { return *d; }
    inline T *operator->() { return d; }
    inline const T *operator->() const { return d; }
    inline operator T *() { return d; }
    inline operator const T *() const { return d; }
    inline T *data() { return d; }
    inline const T *data() const { return d; }
    inline const T *constData() const { return d; }

    inline bool operator==(const CodeModelPointer<T> &other) const { return d == other.d; }
    inline bool operator!=(const CodeModelPointer<T> &other) const { return d != other.d; }
    inline bool operator==(const T *ptr) const { return d == ptr; }
    inline bool operator!=(const T *ptr) const { return d != ptr; }

    inline CodeModelPointer() { d = 0; }
    inline ~CodeModelPointer() { if (d && !d->ref.deref()) delete d; }

    explicit CodeModelPointer(T *data);
    inline CodeModelPointer(const CodeModelPointer<T> &o) : d(o.d) { if (d) d->ref.ref(); }
    inline CodeModelPointer<T> & operator=(const CodeModelPointer<T> &o) {
        if (o.d != d) {
            T *x = o.d;
            if (x) x->ref.ref();
            x = qAtomicSetPtr(&d, x);
            if (x && !x->ref.deref())
                delete x;
        }
        return *this;
    }
    inline CodeModelPointer &operator=(T *o) {
        if (o != d) {
            T *x = o;
            if (x) x->ref.ref();
            x = qAtomicSetPtr(&d, x);
            if (x && !x->ref.deref())
                delete x;
        }
        return *this;
    }

    inline bool operator!() const { return !d; }

private:

    T *d;
};

template <class T>
Q_INLINE_TEMPLATE CodeModelPointer<T>::CodeModelPointer(T *adata) : d(adata)
{ if (d) d->ref.ref(); }

#endif // CODEMODEL_POINTER_H
