# Binary Tree: A tree whose elements have at most 2 children is called a binary tree.
# Since each element in a binary tree can have only 2 children, we typically name them the left and right child.
# For the tree to be more efficient than a linked list we need to organize the branches so that:
# Left node value < Right node value
# This will allow us to traverse the tree at the Time Efficiency of O(log n) as we cut the tree by 1/2 at each level.
# This makes the tree a Binary Search Tree.
# Types of Binary Trees: https://en.wikipedia.org/wiki/Binary_tree#Types_of_binary_trees
#
#                     8 --> root node
# left branch <-- /         \ --> right branch
#                4          12
#               / \        /  \
#              2   6     10    14
#             /\  / \   / \    / \
#            1 3 5  7 9   11 13  15 --> leaf nodes
#
# Time complexity:  O(log n)
# Space complexity: O(n)
class Node:
    def __init__(self, value=None):
        # Each node contains a value and  pointers to up to 2 child nodes (left & right), left < right
        if value is None:
            raise ValueError('Must pass a value to Node()')
        self.value = value
        self.left  = None
        self.right = None

    def add(self, value=None):
        # Recursive method
        # Traverse down the tree
        # Pick either left or right node depending on wheather value to be added is less than (left node)
        # Or greater than (right node) value of current node
        #
        # BinaryTree.add(13)
        #
        #                        8 --> root node, 13 > 8 --> right branch
        #    left branch <-- /         \ --> right branch
        #                   4          12 --> 13 > 12 --> right branch
        #                  / \        /  \
        #                 2   6     10    14 --> 13 < 14 --> left branch
        #                /\  / \   / \      \
        # leaf nodes <-- 1 3 5  7 9   11     15 --> add left node with value 13
        #
        # Time complexity:  O(log n)
        # Space complexity: O(1)
        if value is None:
            raise ValueError('Must pass a value to Node.add()')

        # value to insert already in tree
        if value == self.value:
            return True

        # value to insert less than current node value
        # Traverse left
        if value < self.value:
            if self.left:
                # Continue recursion down the tree
                return self.left.add(value)
            else:
                # Add new node with value
                self.left = Node(value)
                return True

        # value to insert greater than current node value
        # Traverse right
        if value > self.value:
            if self.right:
                # Continue recursion down the tree
                return self.right.add(value)
            else:
                # Add new node with value
                self.right = Node(value)
                return True

        return False

    def remove(self, parent=None, value=None):
        # Recursive method
        # Traverse down the tree
        # Pick either left or right node depending on wheather value to be removed is less than (left node)
        # Or greater than (right node) value of current node
        # Once we find the node with the value to be removed
        # We need to replace it with the greater value of the two nodes below it,
        # And so on until we reach the bottom of the tree
        #
        # BinaryTree.remove(12)
        #
        #                        8 --> root node
        #    left branch <-- /         \ --> right branch
        #                   4          12 --> replace self.value with 14
        #                  / \        /  \
        #                 2   6     10    14 --> replace self.value with 15
        #                /\  / \   / \    / \
        # leaf nodes <-- 1 3 5  7 9   11 13  15 --> now this node is a duplicate, unlink from parent node
        #
        # Time complexity:  O(log n)
        # Space complexity: O(1)
        if value is None:
            raise ValueError('Must pass a value to Node.remove()')

        # Found the node with the value
        # We will replace its value with the value of the node (right or left) below it
        # If the node doesn't contain any sub nodes we will remove a link to it from the parent node
        if value == self.value:
            if self.right is not None:
                # Right sub node present, move its value up one node and continue traversing right
                self.value = self.right.value
                self.right.remove(self, self.right.value)
            elif self.left is not None:
                # Left sub node present, move its value up one node and continue traversing left
                self.value = self.left.value
                self.left.remove(self, self.left.value)
            elif parent.right is not None:
                # We've reached the bottom of the tree traversing right
                # Since we've moved nodes up the tree, this node is now a duplicate of its parent node
                # Unlink the node from the parent and we're done
                parent.right = None
                return True
            elif parent.left is not None:
                # We've reached the bottom of the tree traversing left
                # Since we've moved nodes up the tree, this node is now a duplicate of its parent node
                # Unlink the node from the paren and we're done
                parent.left = None
                return True

        # value to remove less than current node value
        # Traverse left
        if value < self.value:
            if self.left:
                self.left.remove(self, value)
            else:
                # We did not find the value to remove
                return False

        # value to remove greater than current node value
        # Traverse right
        if value > self.value:
            if self.right:
                self.right.remove(self, value)
            else:
                # We did not find the value to remove
                return False

    def sorted(self):
        # Recursive method
        # Sort the tree in ascending order
        # Traverse down the tree
        # First the left branch all the way down to the leaf node
        # Once we reach the left-most leaf node the order of output should be:
        # 1. left-most leaf node (1)
        # 2. parent node (2)
        # 3. parent.right node (3)
        # 4. parent.parent node (4)
        # 5. parent.parent.right.left (5)
        # And repeat
        #
        #                     8 --> root node
        # left branch <-- /         \ --> right branch
        #                4          12
        #               / \        /  \
        #              2   6     10    14
        #             /\  / \   / \    / \
        #            1  3 5  7 9   11 13  15 --> leaf nodes
        #
        if self.left:
            for v in self.left.sorted():
                yield v

        yield self.value

        if self.right:
            for v in self.right.sorted():
                yield v

    def reversed(self):
        # Recursive method
        # Sort the tree in descending order
        # Traverse down the tree
        # First the left branch all the way down to the leaf node
        # Once we reach the left-most leaf node the order of output should be:
        # 1. right-most leaf node (15)
        # 2. parent node (14)
        # 3. parent.left node (13)
        # 4. parent.parent node (12)
        # 5. parent.parent.left.right (10)
        # And repeat
        #
        #                     8 --> root node
        # left branch <-- /         \ --> right branch
        #                4          12
        #               / \        /  \
        #              2   6     10    14
        #             /\  / \   / \    / \
        #            1  3 5  7 9   11 13  15 --> leaf nodes
        #
        if self.right:
            for v in self.right.reversed():
                yield v

        yield self.value

        if self.left:
            for v in self.left.reversed():
                yield v


class BinaryTree:
    def __init__(self, value=None):
        if value:
            self.root = Node(value)
        else:
            self.root = None

    def add(self, value=None):
        # If value < parent.value add a node and link it to parent.left
        # If value > parent.value add a node and link it to parent.right
        if value is None:
            raise ValueError('Must pass a value to BanaryTree.add()')

        if self.root is None:
            self.root = Node(value)
            return True

        # Recursive version
        return self.root.add(value)

    def remove(self, value=None):
        if value is None:
            raise ValueError('Must pass a value to BinaryTree.remove()')

        if self.root is None:
            return False

        parent = None
        return self.root.remove(parent, value)

    def min(self):
        # Find the node with the smallest value in the tree
        # Start at root and traverse left to the bottom of the tree where the smallest value resides
        #
        #                     8 --> root node
        # left branch <-- /         \ --> right branch
        #                4          12
        #               / \        /  \
        #              2   6     10    14
        #             /\  / \   / \    / \
        #            1  3 5  7 9   11 13  15 --> leaf nodes
        #
        node = self.root
        while node:
            # Traverse left
            if node.left:
                node = node.left
            else:
                return node.value
        return None

    def max(self):
        # Find the node with the largest value in the tree
        # Start at root and traverse right to the bottom of the tree where the largest value resides
        #
        #                     8 --> root node
        # left branch <-- /         \ --> right branch
        #                4          12
        #               / \        /  \
        #              2   6     10    14
        #             /\  / \   / \    / \
        #            1  3 5  7 9   11 13  15 --> leaf nodes
        #
        node = self.root
        while node:
            # Traverse right
            if node.right:
                node = node.right
            else:
                return node.value
        return None

    def closest(self, value=None):
        # Find the node with the value closest to the searched value including itself
        #
        #                     8 --> root node
        # left branch <-- /         \ --> right branch
        #                4          12
        #               / \        /  \
        #              2   6     10    14
        #             /\  / \   / \    / \
        #            1  3 5  7 9   11 13  15 --> leaf nodes
        #
        if value is None:
            raise ValueError('Must pass a value to BinaryTree.closest()')

        if self.root is None:
            return None

        node = self.root
        best = node
        distance = abs(node.value - value)
        while node:
            if abs(node.value - value) < distance:
                best = node
                distance = abs(node.value - value)
            if value < node.value:
                node = node.left
            if value > node.value:
                node = node.right
            else:
                return node.value
        return best.value

    def sorted(self):
        if self.root is None:
            return None
        for v in self.root.sorted():
            yield v

    def reversed(self):
        if self.root is None:
            return None
        for v in self.root.reversed():
            yield v

    def __iter__(self):
        if self.root is None:
            return None
        for v in self.root.sorted():
            yield v

    def __contains__(self, value=None):
        # Find the node containing the value
        # Overwrites the 'in' keyword, as in:
        # 'for v in list:' or '5 in list'
        #
        #                     8 --> root node
        # left branch <-- /         \ --> right branch
        #                4          12
        #               / \        /  \
        #              2   6     10    14
        #             /\  / \   / \    / \
        #            1  3 5  7 9   11 13  15 --> leaf nodes
        #
        if value is None:
            raise ValueError('Must pass a value to BinaryTree.__contains__()')

        node = self.root
        while node:
            # Traverse the tree picking either left or right branch
            if value == node.value:
                return True
            elif value < node.value:
                node = node.left
            else:
                node = node.right
        return False

