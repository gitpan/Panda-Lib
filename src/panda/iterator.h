#pragma once
#include <iterator> // iterator_traits

namespace panda {

template <class IterType> class base_iterator {
public:
    typedef IterType                                                        iterator_type;
    typedef typename std::iterator_traits<iterator_type>::iterator_category iterator_category;
    typedef typename std::iterator_traits<iterator_type>::value_type        value_type;
    typedef typename std::iterator_traits<iterator_type>::difference_type   difference_type;
    typedef typename std::iterator_traits<iterator_type>::pointer           pointer;
    typedef typename std::iterator_traits<iterator_type>::reference         reference;

private:
    iterator_type _ptr;

public:
    base_iterator () throw() {}

    base_iterator (iterator_type ptr) throw() : _ptr(ptr) {}

    template <class IterType2> base_iterator(const base_iterator<IterType2>& it) throw() : _ptr(it.base()) {}

    reference      operator*  () const throw() { return *_ptr; }
    pointer        operator-> () const throw() { return (pointer)&reinterpret_cast<const volatile char&>(*_ptr); }
    base_iterator& operator++ ()       throw() { ++_ptr; return *this; }
    base_iterator  operator++ (int)    throw() { base_iterator tmp(*this); ++(*this); return tmp; }
    base_iterator& operator-- ()       throw() { --_ptr; return *this; }
    base_iterator  operator-- (int)    throw() { base_iterator tmp(*this); --(*this); return tmp; }

    base_iterator  operator+  (difference_type n) const throw() { base_iterator it(*this); it += n; return it; }
    base_iterator& operator+= (difference_type n)       throw() { _ptr += n; return *this; }
    base_iterator  operator-  (difference_type n) const throw() { return *this + (-n); }
    base_iterator& operator-= (difference_type n)       throw() { *this += -n; return *this; }
    reference      operator[] (difference_type n) const throw() { return _ptr[n]; }

    iterator_type base () const throw() { return _ptr; }
};

template <class Iter1, class Iter2> inline bool operator== (const base_iterator<Iter1>& x, const base_iterator<Iter2>& y) throw() {
    return x.base() == y.base();
}

template <class Iter1, class Iter2> inline bool operator< (const base_iterator<Iter1>& x, const base_iterator<Iter2>& y) throw() {
    return x.base() < y.base();
}

template <class Iter1, class Iter2> inline bool operator!= (const base_iterator<Iter1>& x, const base_iterator<Iter2>& y) throw() {
    return !(x == y);
}

template <class Iter1, class Iter2> inline bool operator> (const base_iterator<Iter1>& x, const base_iterator<Iter2>& y) throw() {
    return y < x;
}

template <class Iter1, class Iter2> inline bool operator>= (const base_iterator<Iter1>& x, const base_iterator<Iter2>& y) throw() {
    return !(x < y);
}

template <class Iter1, class Iter2> inline bool operator<= (const base_iterator<Iter1>& x, const base_iterator<Iter2>& y) throw() {
    return !(y < x);
}

template <class Iter> inline bool operator!= (const base_iterator<Iter>& x, const base_iterator<Iter>& y) throw() {
    return !(x == y);
}

template <class Iter> inline bool operator> (const base_iterator<Iter>& x, const base_iterator<Iter>& y) throw() {
    return y < x;
}

template <class Iter> inline bool operator>= (const base_iterator<Iter>& x, const base_iterator<Iter>& y) throw() {
    return !(x < y);
}

template <class Iter> inline bool operator<= (const base_iterator<Iter>& x, const base_iterator<Iter>& y) throw() {
    return !(y < x);
}

template <class Iter1, class Iter2> inline typename base_iterator<Iter1>::difference_type
operator- (const base_iterator<Iter1>& x, const base_iterator<Iter2>& y) throw() {
    return x.base() - y.base();
}

template <class Iter> inline base_iterator<Iter> operator+(typename base_iterator<Iter>::difference_type n, base_iterator<Iter> x) throw() {
    x += n;
    return x;
}

};
