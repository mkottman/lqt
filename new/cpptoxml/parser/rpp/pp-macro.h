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
  Copyright 2005 Roberto Raggi <roberto@kdevelop.org>

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

#ifndef PP_MACRO_H
#define PP_MACRO_H

namespace rpp {

struct pp_macro
{
#if defined (PP_WITH_MACRO_POSITION)
  pp_fast_string const *file;
#endif
  pp_fast_string const *name;
  pp_fast_string const *definition;
  std::vector<pp_fast_string const *> formals;

  union
  {
    int unsigned state;

    struct
    {
      int unsigned hidden: 1;
      int unsigned function_like: 1;
      int unsigned variadics: 1;
    };
  };

  int lines;
  pp_macro *next;
  std::size_t hash_code;

  inline pp_macro():
#if defined (PP_WITH_MACRO_POSITION)
    file (0),
#endif
    name (0),
    definition (0),
    state (0),
    lines (0),
    next (0),
    hash_code (0)
    {}
};

} // namespace rpp

#endif // PP_MACRO_H

// kate: space-indent on; indent-width 2; replace-tabs on;
