import uuid

from django.test import TestCase

from django.contrib.auth.models import User
from customers.models import Customer


class CustomerTestCase(TestCase):
    def setUp(self):
        user = User.objects.create(
            username='customer',
            password='password',
            first_name='John',
            last_name='Doe'
        )
        Customer.objects.create(
            user=user
        )

    def test_customer_id(self):
        user = User.objects.get(username='customer')
        customer = Customer.objects.get(user=user)

        self.assertIsInstance(customer.customer_id, uuid.UUID)

    def test_customer_name(self):
        user = User.objects.get(username='customer')
        customer = Customer.objects.get(user=user)

        self.assertEqual(customer.first_name, 'John')
        self.assertEqual(customer.last_name, 'Doe')
        self.assertEqual(customer.full_name, 'John Doe')

    def test_user_not_customer(self):
        user_not_customer = User.objects.create(
            username='user_not_customer',
            password='password',
            first_name='James',
            last_name='Dean'
        )

        self.assertNotIsInstance(user_not_customer, Customer)
