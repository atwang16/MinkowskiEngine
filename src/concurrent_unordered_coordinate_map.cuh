/*
 *  Copyright (c) 2020 NVIDIA CORPORATION.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
#ifndef COORDINATE_MAP_CUH
#define COORDINATE_MAP_CUH

#include "types.hpp"

#include "3rdparty/concurrent_unordered_map.cuh"
#include "3rdparty/hash/helper_functions.cuh"
#include "coordinate_map_functors.cuh"

#include <memory>
#include <thrust/device_vector.h>

namespace minkowski {

namespace detail {} // namespace detail

// unordered_map wrapper
// clang-format off
template <typename coordinate_type,
          typename Allocator = default_allocator<thrust::pair<coordinate<coordinate_type>, default_types::index_type>>,
          typename Hash      = detail::coordinate_murmur3<coordinate_type>,
          typename KeyEqual  = detail::coordinate_equal_to<coordinate_type>>
class ConcurrentCoordinateUnorderedMap {
public:
  using size_type      = default_types::size_type;
  using key_type       = coordinate<coordinate_type>;
  using mapped_type    = default_types::index_type;
  using value_type     = std::pair<key_type, mapped_type>;
  using hasher         = Hash;
  using key_equal      = KeyEqual;
  using allocator_type = Allocator;
  using map_type = concurrent_unordered_map<key_type,        // key
                                            mapped_type,     // mapped_type
                                            hasher,          // hasher
                                            key_equal,       // equality
                                            allocator_type>; // allocator
  using iterator       = typename map_type::iterator;
  using const_iterator = typename map_type::const_iterator;
  using is_used_type   = detail::is_used<key_type, mapped_type, coordinate_equal_to<coordinate_type>>;

public:
  ConcurrentCoordinateUnorderedMap(size_type const number_of_coordinates,
                                   size_type const coordinate_size,
                                   allocator_type &allocator = allocator_type())
      : m_hasher(detail::coordinate_murmur3<coordinate_type>{coordinate_size}),
        m_equal(detail::coordinate_equal_to<coordinate_type>{coordinate_size}),
        m_unused_key(coordinate<coordinate_type>{nullptr}),
        m_unused_element(std::numeric_limits<coordinate_type>::max()) {

    m_map =
        map_type(compute_hash_table_size(number_of_coordinates),
                 m_unused_element, m_unused_key, m_hasher, m_equal, allocator);
  }
  ~ConcurrentCoordinateUnorderedMap() { m_map.destroy(); }

  // Iterators
  __device__ iterator begin() { return m_map.begin(); }
  __device__ const_iterator begin() const { return m_map.begin(); }

  __device__ iterator end() { return m_map.end(); }
  __device__ const_iterator end() const { return m_map.end(); }

  __device__ iterator find(key_type const &key) { return m_map.find(key); }
  __device__ const_iterator find(key_type const &key) const { return m_map.find(key); }

  __device__ thrust::pair<iterator, bool> insert(value_type const &insert_pair) {
    return m_map.insert(keyval);
  }

  size_type size() {
    return thrust::count_if(thrust::device,
                            cmap.data(),                   // begin
                            cmap.data() + cmap.capacity(), // end
                            is_used_type(m_unused_key, m_equal));
  }

  ConcurrentCoordinateUnorderedMap()                                         = delete;
  ConcurrentCoordinateUnorderedMap(ConcurrentCoordinateUnorderedMap const &) = default;
  ConcurrentCoordinateUnorderedMap(ConcurrentCoordinateUnorderedMap &&)      = default;
  // clang-format on

private:
  hasher const m_hasher;
  key_equal const m_equal;
  key_type const m_unused_key;
  mapped_type const m_unused_element;
  map_type m_map;
};

} // namespace minkowski

#endif // COORDINATE_MAP_CUH