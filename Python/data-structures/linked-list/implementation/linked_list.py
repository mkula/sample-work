"""
A linked list is a pointer based data structure whose elements/nodes although organized (through abstraction) in a linear fashion
are stored randomly in memory.

head                     tail
 5 -> 3 -> 1 -> 7 -> 5 -> 4

A linked list is more efficient than an array for some operations and less efficient for others:

t - time complexity
s - space complexity

------------------------------------
Operation | LinkedList | ArrayList |
------------------------------------
Access    | t: O(n)    | t: O(1)   |
------------------------------------
Insert    | t: O(1)    | t: O(n)   |
------------------------------------
Append    | t: O(1)    | t: O(1)   |
------------------------------------
Shift     | t: O(1)    | t: O(n)   |
------------------------------------
Pop       | t: O(1)    | t: O(1)   |
------------------------------------
Search    | t: O(n)    | t: O(n)   |
------------------------------------
Iterate   | t: O(n)    | t: O(n)   |
------------------------------------
Index     | t: O(n)    | t: O(1)   |
------------------------------------
Length    | t: O(1)    | t: O(1)   |
------------------------------------
XXXXXXXXX | s: O(n)    | s: O(n)   |
------------------------------------

Note:
Generally speaking, linked lists and arrays have the same space complexity as both data structures require O(n) of memory allocation.
However, in some operations arrays have higher space complexity as they require more memory space to be allocated to perform the operation.
Eg. To append a value to the end of an array whose allocated memory is fully occupied, the append operation will need to allocate memory for an additional array that is usually twice the size of the original array, and then copy the values from the old aray over to the new array, and then append the additional value to the new array, s: O(n+m).
"""
import unittest


class Node(object):
    """Node represents a single element in a linked list containing a value and a pointer to the next element in the list.

    O(1) - time complexity
    O(1) - space complexity
    """
    def __init__(self, value=None, next=None):
        self.value = value
        self.next  = next


class LinkedList(object):
    def __init__(self):
        """Initialize a linked list.

        >>> ll = LinkedList()

        O(1) - time complexity
        """
        self.head  = None # first node of a linked list
        self.tail  = None # last node of a linked list
        self._count = 0    # number of nodes in a linked list


    def __len__(self):
        """Python special method which will allow us to use a linked list with `len()`.

        Return: Number of elements in a linked list.

        >>> len(ll)
        4

        O(1) = time complexity
        """
        return self._count


    def __str__(self):
        """Python special method which will allow us to use a linked list with `print()`.

        Return: String representation of a linked list.

        >>> print(ll)
        3 -> 4 -> 1 -> 7

        O(n) - time complexity
        """
        l = ''
        current = self.head
        while current:
            if current is not self.head:
                l += ' -> '
            l += '{0}'.format(current.value)
            current = current.next

        return l


    def __repr__(self):
        """Python special method which will allow us to print a linked list in Python console.

        Return: String for a printable representation of a linked list.

        >>> ll
        3 -> 4 -> 1 -> 7

        O(n) - time complexity
        """
        l = ''
        current = self.head
        while current:
            if current is not self.head:
                l += ' -> '
            l += '{0}'.format(current.value)
            current = current.next

        return l


    def __iter__(self):
        """Python special method which will allow us to use a linked list with 'for in'.

        Return: Iterator representing the elements of a linked list.

        >>> for v in ll:
        ...     print(v)
        ...
        3
        4
        1
        7

        O(n) - time complexity
        """
        current = self.head
        while current:
            yield current.value
            current = current.next


    def __contains__(self, value):
        """Python special method which will allow us to use a linked list with 'in'.

        Return: True if value exists, False otherwise.

        >>> 4 in ll
        True

        O(n) - time complexity
        """
        if value is None:
            raise ValueError('Must provide a value to check for its presence.')

        current = self.head
        while current:
            if current.value == value:
                return True
            current = current.next

        return False


    def length(self):
        """Get the length of a linked list.

        Return: Number of elements in a linked list.

        >>> ll.length()
        4

        O(1) = time complexity
        """
        return self._count


    def show(self):
        """Print the contents of a linked list.

        >>> ll.show()
        3 -> 4 -> 1 -> 7

        O(n) = time complexity
        """
        print(self)


    def insert(self, value):
        """Insert a value at the begining of a linked list.

        Return: New length of the list.

        >>> ll.insert(3)
        1

        O(1) = time complexity
        """
        if value is None:
            raise ValueError('Must provide a value to insert.')

        if self.head:
            # head already holds the first node
            # add new node, replace head with the new node, retain reference to old _head
            self.head = Node(value, self._head)
        else:
            # head doens't hold a node, therefore tail doesn't hold a node either
            # add new node, let head and tail reference it
            self.head = self.tail = Node(value, None)

        # adjust the count of elements in the linked list
        self._count += 1

        return self._count


    def append(self, value):
        """Append a value to the end of a linked list.

        Return: New length of the list.

        >>> ll.append(4)
        2

        O(1) = time complexity
        """
        if value is None:
            raise ValueError('Must provide a value to append.')

        if self.tail:
            # tail already holds the last node
            # add new node, make old tail reference the new node
            tail = self.tail
            tail.next = self.tail = Node(value, None)
        else:
            # tail doesn't hold a node, therefore head doesn't hold a node either
            # add new node, let head and tail reference the new node
            self.head = self.tail = Node(value, None)

        # adjust the _count of elements in the linked list
        self._count += 1

        return self._count


    def shift(self):
        """Remove the first element from a linked list.

        Return: The value removed or None.

        >>> ll.shift()
        3

        O(1) = time complexity
        """
        value = None
        if self.head:
            # the linked list contains at least one element/node
            # remove the first element from it, and shift the list to the left
            value = self.head.value
            self.head = self._head.next

            # if there are no more elements/nodes in the linked list
            # then head & tail should be set to None
            if self.head is None:
                self.tail = None

        # adjust the _count of elements in the linked list if we removed a value
        if value:
            self._count -= 1

        return value


    def pop(self):
        """Remove the last element from a linked list.

        Retur: The value removed or None.

        >>> ll.pop()
        7

        O(n) = time complexity
        """
        # step through the linked list starting at head
        # stop at _count - 1
        i = 1

        value   = None
        current = self.head
        while current:
            # to remove the last element/node of the linked list
            # we want to stop at the second to last element/node and set its next pointer to None
            # unless there's only one element/node in the linked list
            # in that case we need to set head & tail to None
            if self._count == 1:
                value = current.value
                self.head = self.tail = None
            elif i == self._count - 1:
                # get the value of the last element/node in the linked list
                value = current.next.value
                # remove the last element/node from the linked list
                current.next = None
            current = current.next
            i += 1

        # adjust the _count of elements in the linked list if we removed a value
        if value:
            self._count -= 1

        return value


class TestLinkedList(unittest.TestCase):
    def test_in(self):
        ll = LinkedList()
        ll.append(1)
        ll.append(2)
        ll.append(3)
        ll.append(4)
        self.assertTrue(1 in ll)
        self.assertTrue(2 in ll)
        self.assertTrue(3 in ll)
        self.assertTrue(4 in ll)
        with self.assertRaises(ValueError):
            None in ll

    def test_len(self):
        ll = LinkedList()
        ll.append(1)
        self.assertEqual(len(ll), 1)
        ll.append(2)
        self.assertEqual(len(ll), 2)
        ll.append(3)
        self.assertEqual(len(ll), 3)
        ll.append(4)
        self.assertEqual(len(ll), 4)

    def test_length(self):
        ll = LinkedList()
        ll.append(1)
        self.assertEqual(ll.length(), 1)
        ll.append(2)
        self.assertEqual(ll.length(), 2)
        ll.append(3)
        self.assertEqual(ll.length(), 3)
        ll.append(4)
        self.assertEqual(ll.length(), 4)

    def test_show(self):
        ll = LinkedList()
        ll.append(1)
        ll.append(2)
        ll.append(3)
        ll.append(4)
        self.assertEqual(ll.__str__(), '1 -> 2 -> 3 -> 4')

    def test_insert(self):
        ll = LinkedList()
        self.assertEqual(ll.insert(1), 1)
        self.assertEqual(ll.insert(2), 2)
        self.assertEqual(ll.insert(3), 3)
        self.assertEqual(ll.insert(4), 4)
        self.assertEqual(ll.__str__(), '4 -> 3 -> 2 -> 1')

    def test_append(self):
        ll = LinkedList()
        self.assertEqual(ll.append(1), 1)
        self.assertEqual(ll.append(2), 2)
        self.assertEqual(ll.append(3), 3)
        self.assertEqual(ll.append(4), 4)
        self.assertEqual(ll.__str__(), '1 -> 2 -> 3 -> 4')

    def test_insert_append(self):
        ll = LinkedList()
        self.assertEqual(ll.insert(1), 1)
        self.assertEqual(ll.append(2), 2)
        self.assertEqual(ll.insert(3), 3)
        self.assertEqual(ll.append(4), 4)
        self.assertEqual(ll.__str__(), '3 -> 1 -> 2 -> 4')

    def test_append_insert(self):
        ll = LinkedList()
        self.assertEqual(ll.append(1), 1)
        self.assertEqual(ll.insert(2), 2)
        self.assertEqual(ll.append(3), 3)
        self.assertEqual(ll.insert(4), 4)
        self.assertEqual(ll.__str__(), '4 -> 2 -> 1 -> 3')

    def test_shift(self):
        ll = LinkedList()
        ll.append(1)
        ll.append(2)
        ll.append(3)
        ll.append(4)
        self.assertEqual(ll.shift(), 1)
        self.assertEqual(ll.length(), 3)
        self.assertEqual(ll.__str__(), '2 -> 3 -> 4')
        self.assertEqual(ll.shift(), 2)
        self.assertEqual(ll.length(), 2)
        self.assertEqual(ll.__str__(), '3 -> 4')
        self.assertEqual(ll.shift(), 3)
        self.assertEqual(ll.length(), 1)
        self.assertEqual(ll.__str__(), '4')
        self.assertEqual(ll.shift(), 4)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.shift(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.shift(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')

    def test_pop(self):
        ll = LinkedList()
        ll.append(1)
        ll.append(2)
        ll.append(3)
        ll.append(4)
        self.assertEqual(ll.pop(), 4)
        self.assertEqual(ll.length(), 3)
        self.assertEqual(ll.__str__(), '1 -> 2 -> 3')
        self.assertEqual(ll.pop(), 3)
        self.assertEqual(ll.length(), 2)
        self.assertEqual(ll.__str__(), '1 -> 2')
        self.assertEqual(ll.pop(), 2)
        self.assertEqual(ll.length(), 1)
        self.assertEqual(ll.__str__(), '1')
        self.assertEqual(ll.pop(), 1)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.pop(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.pop(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')

    def test_shift_pop(self):
        ll = LinkedList()
        ll.append(1)
        ll.append(2)
        ll.append(3)
        ll.append(4)
        self.assertEqual(ll.shift(), 1)
        self.assertEqual(ll.length(), 3)
        self.assertEqual(ll.__str__(), '2 -> 3 -> 4')
        self.assertEqual(ll.pop(), 4)
        self.assertEqual(ll.length(), 2)
        self.assertEqual(ll.__str__(), '2 -> 3')
        self.assertEqual(ll.shift(), 2)
        self.assertEqual(ll.length(), 1)
        self.assertEqual(ll.__str__(), '3')
        self.assertEqual(ll.pop(), 3)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.shift(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.pop(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')

    def test_pop_shift(self):
        ll = LinkedList()
        ll.append(1)
        ll.append(2)
        ll.append(3)
        ll.append(4)
        self.assertEqual(ll.pop(), 4)
        self.assertEqual(ll.length(), 3)
        self.assertEqual(ll.__str__(), '1 -> 2 -> 3')
        self.assertEqual(ll.shift(), 1)
        self.assertEqual(ll.length(), 2)
        self.assertEqual(ll.__str__(), '2 -> 3')
        self.assertEqual(ll.pop(), 3)
        self.assertEqual(ll.length(), 1)
        self.assertEqual(ll.__str__(), '2')
        self.assertEqual(ll.shift(), 2)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.pop(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')
        self.assertEqual(ll.shift(), None)
        self.assertEqual(ll.length(), 0)
        self.assertEqual(ll.__str__(), '')


"""
if __name__ == '__main__':
    unittest.main()
"""
