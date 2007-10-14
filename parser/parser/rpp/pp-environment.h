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

#ifndef PP_ENVIRONMENT_H
#define PP_ENVIRONMENT_H

#include <vector>
#include <cstring>

namespace rpp {

class pp_environment
{
public:
  typedef std::vector<pp_macro*>::const_iterator const_iterator;

public:
  pp_environment ():
    current_line (0),
    _M_hash_size (4093)
  {
    _M_base = (pp_macro **) memset (new pp_macro* [_M_hash_size], 0, _M_hash_size * sizeof (pp_macro*));
  }

  ~pp_environment ()
  {
    for (std::size_t i = 0; i < _M_macros.size (); ++i)
      delete _M_macros [i];

    delete [] _M_base;
  }

  const_iterator first_macro () const { return _M_macros.begin (); }
  const_iterator last_macro () const { return _M_macros.end (); }

  inline void bind (pp_fast_string const *__name, pp_macro const &__macro)
  {
    std::size_t h = hash_code (*__name) % _M_hash_size;
    pp_macro *m = new pp_macro (__macro);
    m->name = __name;
    m->next = _M_base [h];
    m->hash_code = h;
    _M_base [h] = m;

    _M_macros.push_back (m);

    if (_M_macros.size() == _M_hash_size)
      rehash();
  }

  inline void unbind (pp_fast_string const *__name)
  {
    if (pp_macro *m = resolve (__name))
      m->hidden = true;
  }

  inline void unbind (char const *__s, std::size_t __size)
  {
    pp_fast_string __tmp (__s, __size);
    unbind (&__tmp);
  }

  inline pp_macro *resolve (pp_fast_string const *__name) const
  {
    std::size_t h = hash_code (*__name) % _M_hash_size;
    pp_macro *it = _M_base [h];

    while (it && it->name && it->hash_code == h && (*it->name != *__name || it->hidden))
      it = it->next;

    return it;
  }

  inline pp_macro *resolve (char const *__data, std::size_t __size) const
  {
    pp_fast_string const __tmp (__data, __size);
    return resolve (&__tmp);
  }

  std::string current_file;
  int current_line;

private:
  inline std::size_t hash_code (pp_fast_string const &s) const
  {
    std::size_t hash_value = 0;

    for (std::size_t i = 0; i < s.size (); ++i)
      hash_value = (hash_value << 5) - hash_value + s.at (i);

    return hash_value;
  }

  void rehash()
  {
    delete[] _M_base;

    _M_hash_size <<= 1;

    _M_base = (pp_macro **) memset (new pp_macro* [_M_hash_size], 0, _M_hash_size * sizeof(pp_macro*));
    for (std::size_t index = 0; index < _M_macros.size (); ++index)
      {
        pp_macro *elt = _M_macros [index];
        std::size_t h = hash_code (*elt->name) % _M_hash_size;
        elt->next = _M_base [h];
        elt->hash_code = h;
        _M_base [h] = elt;
      }
  }

private:
  std::vector<pp_macro*> _M_macros;
  pp_macro **_M_base;
  std::size_t _M_hash_size;
};

} // namespace rpp

#endif // PP_ENVIRONMENT_H

// kate: space-indent on; indent-width 2; replace-tabs on;
