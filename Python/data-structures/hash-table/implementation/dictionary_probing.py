"""
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
Delete    | t: O(1)      | t: O(n)              |
-------------------------------------------------
Insert    | t: O(1)      | t: O(n)              |
-------------------------------------------------
Iterate   | t: O(n)      | t: O(n)              |
-------------------------------------------------
Search    | t: O(1)      | t: O(n)              |
-------------------------------------------------
Length    | t: O(1)      | t: O(1)              |
-------------------------------------------------
XXXXXXXXX | s: O(n)      | s: O(n)              |
-------------------------------------------------
"""
import unittest


class Entry(object):
    """Entry represents an element of a dictionary containing key, value, and hash(key).

    O(1) - time complexity
    O(1) - space complexity
    """
    def __init__(self, key=None, value=None, hash=None, next=None):
        if key is None:
            raise ValueError('Must provide key to store in dictionary.')
        if value is None:
            raise ValueError('Must provide value to store in dictionary.')
        if hash is None:
            raise ValueError('Must provide hash to store in dictionary.')

        self.key   = key   # dictionary entry key
        self.value = value # dictionary entry value
        self.hash  = hash  # dictionary entry hash(key)


class Dictionary(object):
    def __init__(self):
        """Initialize a dictionary.

        >>> d = Dictionary()

        O(n) - time complexity
        O(n) - space complexity
        """
        self.count   = 0   # number of elements in dictionary
        self.size    = 8   # size of current array holding pointers to elements in dictionary
        self.load    = 0.7 # load factor 7/10 (7 elements per 10 cells)
        self.mask    = self.size - 1 # mask used to calculate index for key
        self.entries = [None] * self.size # array of pointers to elements in dictionary


    def __len__(self):
        """Python special method which will allow us to use a dictionary with `len()`.

        Return: Number of elements in a dictionary.

        >>> len(d)
        7

        O(1) - time complexity
        """
        return self.count


    def __str__(self):
        """Python special method which will allow us to use a dictionary with `print()`.

        Return: String representation of a dictionary.

        >>> print(d)
        {'a': 1, 'b': 5, 'o': 5, 'h': 5}

        O(n) - time complexity
        """
        d = "{"
        for entry in self.entries:
            # traverse linked list of entries unless entry == None
            while entry:
                d += "'{}': {}, ".format(entry.key, entry.value)
                entry = entry.next
        d = d.rstrip(', ') + "}"

        return d


    def __repr__(self):
        """Python special method which will allow us to print a dictionary in Python console.

        Return: String for a printable representation of a dictionary.

        >>> d
        {'a': 1, 'b': 5, 'o': 5, 'h': 5}

        O(n) - time complexity
        """
        d = "{"
        for entry in self.entries:
            # traverse linked list of entries unless entry == None
            while entry:
                d += "'{}': {}, ".format(entry.key, entry.value)
                entry = entry.next
        d = d.rstrip(', ') + "}"

        return d


    def __iter__(self):
        """Python special method which will allow us to use a dictionary with `for in`.

        Return: Iterator representing the elements of a dictionary.

        >>> for _ in d:
        ...     print(_)
        ...
        a
        b
        o
        h

        O(n) - time complexity
        """
        for entry in self.entries:
            if entry:
                # yield entry
                yield entry.key


    def __contains__(self, key=None):
        """Python special method which will allow us to use a dictionary with `in`.

        Return: True if key exists, False otherwise.

        >>> 'a' in d
        True

        O(n) - time complexity
        """
        if key is None:
            raise ValueError('Must provide key to check for existence in dictionary.')

        hash  = self._get_hash(key)
        index = self._get_index(hash)
        entry = self.entries[index]

        while entry:
            if entry.key == key:
                return True
            entry = entry.next

        return False


    def __setitem__(self, key=None, value=None):
        """Python special method which will allow us to add elements to a dictionary.

        Return: New length of the dictionary

        >>> d['a'] = 1
        1

        O(1) - time complexity
        """
        if key is None:
            raise ValueError('Must provide key to store in dictionary.')
        if value is None:
            raise ValueError('Must provide value to store in dictionary.')

        if self.count > self.size * self.load:
            # double size of array when array is at 7/10 of occupancy
            self._resize_entries()

        hash  = self._get_hash(key)
        index = self._get_index(hash)
        entry = self.entries[index]

        while entry:
            # pointer exists at index, traverse linked list of entries
            if entry.key == key:
                # found key, update it with new value
                entry.value = value
                return self.count
            if entry.next:
                entry = entry.next
            else:
                # key doesn't exist, append entry to linked list
                entry.next = Entry(key, value, hash)
                self.count += 1
                return self.count

        # no pointer at index, add new entry
        self.entries[index] = Entry(key, value, hash)
        self.count += 1

        return self.count


    def __getitem__(self, key=None):
        """Python special method which will allow us to get the value of an element in a dictionary.

        Return: Value if key exists, raises KeyError otherwise.

        >>> d['a']
        1

        O(1) - time complexity
        """
        if key is None:
            raise ValueError('Must provide key to retrieve value.')

        hash  = self._get_hash(key)
        index = self._get_index(hash)
        entry = self.entries[index]

        print('size={}, index={}, key={}, hash={}, entry={}'.format(self.size, index, key, hash, entry))
        while entry:
            print('entry.key={}'.format(entry.key))
            # pointer exists at index, traverse linked list of entries
            if entry.key == key:
                return entry.value
            entry = entry.next

        raise KeyError(key)


    def __delitem__(self, key=None):
        """Python special method which will allow us to remove an element from a dictionary.

        Return: New length of the dictionary if key exists, raises KeyError otherwise.

        >>> del d['a']
        2

        O(1) - time complexity
        """
        if key is None:
            raise ValueError('Must provide key to retrieve value.')

        hash  = self._get_hash(key)
        index = self._get_index(hash)
        entry = self.entries[index]

        last  = None
        while entry:
            # pointer exists at index, traverse linked list of entries
            if entry.key == key:
                # found key
                if last:
                    # more than one entry in linked list
                    # remove entry by linking next entry to last entry
                    last.next = entry.next
                else:
                    # only one entry in linked list, null it
                    entry = None
                self.count -= 1
                return self.count
            last  = entry
            entry = entry.next

        raise KeyError(key)


    def _get_hash(self, key=None):
        """Private helper method to obtain hash for a key.

        Return: String representing a hash for a valid key, raises ValueError otherwise.

        O(1) - time complexity
        """
        if key is None:
            raise ValueError('Must provide key to hash.')

        hash = hash(key)
        if hash is None:
            raise KeyError(key)
        if hash < 0:
            hash = -hash

        return hash


    def _get_index(self, hash=None):
        """Private helper method to obtain array index for a hash (key).

        Return: Integer representing a suitable index of the array for the key, raises IndexError otherwise.

        O(1) - time complexity
        """
        if hash is None:
            raise ValueError('Must provide hash to get index.')

        for index in self._gen_probes(hash):
            if self.entries[index] is None:
                return index


    def _gen_probes(self, hash):
        """Private helper method to generate probes of empty array slots.

        Return: Yields open slot index.

        O(n) - time complexity
        """
        if hash is None:
            raise ValueError('Must provide hash to get probes.')

        if self.count == 0:
            self._resize_entries()

        index = hash & self.mask
        yield index

        shift_by = 5
        while True:
            index = (5 * index + hash + 1) &  0xFFFFFFFFFFFFFFFF # 8 bytes, decimal: 18446744073709551615
            index = index & self.mask

            if index < self.size:
                yield index

            hash >>= shift_by


    def _resize_entries(self):
        """Private helper method which quadruples the size of the entries array when the array is 2/3 full.
        Increasing the size of the array by the power of 2 will allow us to use masking(&) instead of modulus(%)
        in getting a fair distribution of indexes.

        Return: New size of the entries array.

        O(n) - time complexity
        """
        self.size *= 4
        self.mask  = self.size - 1
        entries = [None] * self.size

        # copy entries to new array
        for i, entry in enumerate(self.entries):
            if entry and entry.hash:
                index = self._get_index(entry.hash) # get new index for hash
                entries[index]  = entry # copy entry over to new array at new index, creates additional reference
                self.entries[i] = None  # delete old reference, leaves only one reference
        self.entries = entries

        return self.size


d = Dictionary()
d['a'] = 1
d['b'] = 2
d['c'] = 3
d['d'] = 4
d['e'] = 5
d['f'] = 6
d['g'] = 7
d['h'] = 8
d['i'] = 9
d['j'] = 10
d['k'] = 11
d['l'] = 12
d['m'] = 13
d['n'] = 14
d['o'] = 15

"""
for i, e in enumerate(d):
    print('i={}, key={}, value={}, hash={}, next={}'.format(i, e.key, e.value, e.hash, e.next))

print(d)
print(len(d))


print(d['a'])
print(d['b'])
print(d['c'])
print(d['d'])
print(d['e'])
print(d['f'])
print(d['g'])
print(d['h'])
print(d['i'])
print(d['j'])
print(d['k'])
print(d['l'])
print(d['m'])
print(d['n'])
print(d['o'])
"""

class TestDictionary(unittest.TestCase):
    def test_len(self):
        d = Dictionary()
        d['a'] = 6
        self.assertEqual(len(d), 1)
        d['b'] = 2
        self.assertEqual(len(d), 2)
        d['c'] = 3
        self.assertEqual(len(d), 3)

    def test_str(self):
        d = Dictionary()
        d['a'] = 6
        d['b'] = 2
        d['c'] = 3
        #self.assertEqual(sorted(d.__str__()), "{'a': 6, 'b': 2, 'c': 3}")

    def test_repr(self):
        d = Dictionary()
        d['a'] = 6
        d['b'] = 2
        d['c'] = 3
        #self.assertEqual(print(d), "{'a': 6, 'b': 2, 'c': 3}")

    def test_iter(self):
        d = Dictionary()
        d['a'] = 6
        d['b'] = 2
        d['c'] = 3
        #self.assertEqual(print(d), "{'a': 6, 'b': 2, 'c': 3}")

    def test_contains(self):
        d = Dictionary()
        d['a'] = 6
        d['b'] = 2
        d['c'] = 3
        self.assertTrue('a'  in d)
        self.assertTrue('b'  in d)
        self.assertTrue('c'  in d)
        self.assertFalse('x' in d)
        self.assertFalse('y' in d)
        self.assertFalse('z' in d)

        with self.assertRaises(ValueError):
            None in d

    def test_setitem(self):
        d = Dictionary()
        d['a'] = 6
        d['b'] = 2
        d['c'] = 3
        self.assertEqual(d['a'], 6)
        self.assertEqual(d['b'], 2)
        self.assertEqual(d['c'], 3)
        d['a'] = 1
        d['b'] = 2
        d['c'] = 3
        self.assertEqual(d['a'], 1)
        self.assertEqual(d['b'], 2)
        self.assertEqual(d['c'], 3)
        d['d'] = 4
        d['e'] = 5
        d['f'] = 6
        d['g'] = 7
        d['h'] = 8
        d['i'] = 9
        d['j'] = 10
        d['k'] = 11
        d['m'] = 12
        self.assertEqual(len(d), 12)
        self.assertEqual(d['d'], 4)
        self.assertEqual(d['e'], 5)
        self.assertEqual(d['f'], 6)
        self.assertEqual(d['g'], 7)
        #self.assertEqual(d['h'], 8)
        #self.assertEqual(d['i'], 9)
        #self.assertEqual(d['j'], 10)
        #self.assertEqual(d['k'], 11)
        #self.assertEqual(d['m'], 12)

        with self.assertRaises(ValueError):
            d[None] = 7
        with self.assertRaises(ValueError):
            d[d] = None

    def test_getitem(self):
        d = Dictionary()
        d['a'] = 6
        d['b'] = 2
        d['c'] = 3
        self.assertEqual(d['a'], 6)
        self.assertEqual(d['b'], 2)
        self.assertEqual(d['c'], 3)

        with self.assertRaises(ValueError):
            d[None]
        with self.assertRaises(KeyError):
            d['x']

    def test_delitem(self):
        d = Dictionary()
        d['a'] = 6
        d['b'] = 2
        d['c'] = 3
        self.assertEqual(len(d), 3)
        del d['a']
        self.assertEqual(len(d), 2)
        del d['b']
        self.assertEqual(len(d), 1)
        del d['c']
        self.assertEqual(len(d), 0)

        with self.assertRaises(ValueError):
            del d[None]
        with self.assertRaises(KeyError):
            del d['x']

if __name__ == '__main__':
    unittest.main()
