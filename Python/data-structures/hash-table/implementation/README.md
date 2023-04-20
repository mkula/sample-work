Hash Table aka aka Associative Arry aka Dictionary is an array based data structure whose indices store pointers to the elements of the dictionary.
The array index of an element is calculated with the following formula:

i = hash(key) % (len(array) - 1)

The formula may produce collisions where two distinct keys produce the same array index. To resolve this issue we can implement
chaining (Perl implementation of hashes table implementation in Perl) or open addressing (dictionary implementation in Python).

This implementation of a dictionary utilizes the chaining method for collision resolution, where elements with the same array index
are grouped in a linked list.


i - array index, i = hash(key) % (len(array) - 1), if collision add to linked list
p - pointer to first node of linked list of elements of hashes of equal index
e - dictionary elements in order of insertion

-------------------------------------------------------------------
i |       p        |             elements (linked list)           |
-------------------------------------------------------------------
0 | 0x7ff1339cd4c8 | -> e1 {'a': 1} -> e5 {'g': 57} -> e6 {'v': 49}
  |________________|
1 |      None      |
  |________________|
2 |      None      |
  |________________|
3 | 0x7ff13392dd18 | -> e3 {'o': 5}
  |________________|
4 |      None      |
  |________________|
5 | 0x7ff13395ed50 | -> e4 {'h': 5} -> e7 {'e': 17}
  |________________|
6 | 0x7ff1339d92d0 | -> e2 {'b': 5}
  |________________|
7 |      None      |
  |________________|

d = {'a': 1, 'b': 5, 'o': 5, 'h': 5, 'g': 57, 'v': 49, 'e': 17}


t - time complexity
s - space complexity
------------------------------------------------
Operation | Average Case | Amortized Worst Case|
------------------------------------------------
Access    | t: O(1)      | t: O(n)             |
------------------------------------------------
Insert    | t: O(1)      | t: O(n)             |
------------------------------------------------
Delete    | t: O(1)      | t: O(n)             |
------------------------------------------------
Search    | t: O(1)      | t: O(n)             |
------------------------------------------------
Iterate   | t: O(n)      | t: O(n)             |
------------------------------------------------
Length    | t: O(1)      | t: O(1)             |
------------------------------------------------
XXXXXXXXX | s: O(n)      | s: O(n)             |
------------------------------------------------



Dictionary aka Associative Array aka Hash Table is an array based data structure whose indices store pointers to the elements of the dictionary.
The array index of an element is calculated with the following formula:

i = hash(key) % (len(array) - 1)

The formula may produce collisions where two distinct keys produce the same array index. To resolve this issue we can implement
chaining(Perl) or open addressing(Python).

This implementation of a dictionary utilizes the open addressing method for collision resolution, where probing is applied
in searching for alternative open slots in the array. The probing is achieved with the following code:

shift_by = 5
while True:
    index = (5 * index + hash + 1) &  0xFFFFFFFFFFFFFFFF # 8 bytes, decimal: 18,446,744,073,709,551,615
    index = index & self.mask

    if index < self.size:
        yield index

    hash >>= shift_by


i - array index, i = hash(key) % (len(array) - 1), if collision probe for new index
p - pointer to elemeent
e - dictionary elements in order of insertion

------------------------------------
 i |       p        |   elements   |
------------------------------------
 0 | 0x7ff1339cd4c8 | -> e1 {'a': 1}
   |________________|
 1 |      None      |
   |________________|
 2 |      None      |
   |________________|
 3 | 0x7ff13392dd18 | -> e3 {'o': 5}
   |________________|
 4 |      None      |
   |________________|
 5 | 0x7ff13395ed50 | -> e4 {'h': 5}
   |________________|
 6 | 0x7ff1339d92d0 | -> e2 {'b': 5}
   |________________|
 7 |      None      |
   |________________|

d = {'a': 1, 'b': 5, 'o': 5, 'h': 5}


t - time complexity
s - space complexity
-------------------------------------------------
Operation | Average Case | Amortized Worst Case |
-------------------------------------------------
Access    | t: O(1)      | t: O(n)              |
-------------------------------------------------
Insert    | t: O(1)      | t: O(n)              |
-------------------------------------------------
Delete    | t: O(1)      | t: O(n)              |
-------------------------------------------------
Search    | t: O(1)      | t: O(n)              |
-------------------------------------------------
Iterate   | t: O(n)      | t: O(n)              |
-------------------------------------------------
Length    | t: O(1)      | t: O(1)              |
-------------------------------------------------
XXXXXXXXX | s: O(n)      | s: O(n)              |
-------------------------------------------------
