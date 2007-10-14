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

#ifndef PP_ITERATOR_H
#define PP_ITERATOR_H

#include <iterator>

namespace rpp {

class pp_null_output_iterator
  : public std::iterator<std::output_iterator_tag, void, void, void, void>
{
public:
  pp_null_output_iterator() {}

  template <typename _Tp>
  pp_null_output_iterator &operator=(_Tp const &)
  { return *this; }

  inline pp_null_output_iterator &operator * () { return *this; }
  inline pp_null_output_iterator &operator ++ () { return *this; }
  inline pp_null_output_iterator operator ++ (int) { return *this; }
};

template <typename _Container>
class pp_output_iterator
  : public std::iterator<std::output_iterator_tag, void, void, void, void>
{
  std::string &_M_result;

public:
  explicit pp_output_iterator(std::string &__result):
    _M_result (__result) {}

  inline pp_output_iterator &operator=(typename _Container::const_reference __v)
  {
    if (_M_result.capacity () == _M_result.size ())
      _M_result.reserve (_M_result.capacity () << 2);

    _M_result.push_back(__v);
    return *this;
  }

  inline pp_output_iterator &operator * () { return *this; }
  inline pp_output_iterator &operator ++ () { return *this; }
  inline pp_output_iterator operator ++ (int) { return *this; }
};

} // namespace rpp

#endif // PP_ITERATOR_H

// kate: space-indent on; indent-width 2; replace-tabs on;
