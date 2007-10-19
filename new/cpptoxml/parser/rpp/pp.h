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

#ifndef PP_H
#define PP_H

#if defined(_WIN64) || defined(WIN64) || defined(__WIN64__) \
    || defined(_WIN32) || defined(WIN32) || defined(__WIN32__)
#  define PP_OS_WIN
#endif

#include <set>
#include <map>
#include <vector>
#include <string>
#include <iterator>
#include <iostream>
#include <cassert>
#include <cctype>

#include <fcntl.h>

#ifdef HAVE_MMAP
#  include <sys/mman.h>
#endif

#include <sys/stat.h>
#include <sys/types.h>

#if (_MSC_VER >= 1400)
#  define FILENO _fileno
#else
#  define FILENO fileno
#endif

#if defined (PP_OS_WIN)
#  define PATH_SEPARATOR '\\'
#else
#  define PATH_SEPARATOR '/'
#endif

#if defined (RPP_JAMBI)
#  include "rxx_allocator.h"
#else
#  include "rpp-allocator.h"
#endif

#if defined (_MSC_VER)
#  define pp_snprintf _snprintf
#else
#  define pp_snprintf snprintf
#endif

#include "pp-fwd.h"
#include "pp-cctype.h"
#include "pp-string.h"
#include "pp-symbol.h"
#include "pp-internal.h"
#include "pp-iterator.h"
#include "pp-macro.h"
#include "pp-environment.h"
#include "pp-scanner.h"
#include "pp-macro-expander.h"
#include "pp-engine.h"
#include "pp-engine-bits.h"

#endif // PP_H

// kate: space-indent on; indent-width 2; replace-tabs on;
