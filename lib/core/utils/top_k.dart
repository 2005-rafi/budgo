import 'package:collection/collection.dart';

/// Returns the top [k] elements from [elements] using the given [compare] comparator.
///
/// This uses a heap-based approach (via [HeapPriorityQueue]) to run in O(N log K) time
/// rather than sorting the entire list which would take O(N log N) time.
List<T> getTopK<T>(Iterable<T> elements, int k, Comparator<T> compare) {
  if (k <= 0) return [];
  
  // We use a min-heap to track the largest K elements.
  // The element at the top of the heap is the smallest of the K elements.
  final pq = HeapPriorityQueue<T>(compare);
  
  for (final element in elements) {
    pq.add(element);
    if (pq.length > k) {
      pq.removeFirst();
    }
  }
  
  final result = <T>[];
  while (pq.isNotEmpty) {
    result.add(pq.removeFirst());
  }
  
  // Reverse to return from largest to smallest (descending)
  return result.reversed.toList();
}
