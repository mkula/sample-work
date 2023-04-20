import uuid

from django.test import TestCase
from django.core.exceptions import ValidationError

from django.contrib.auth.models import User
from customers.models import Customer
from invoices.models import Invoice, Payment


class InvoiceModelTests(TestCase):
    def setUp(self):
        user = User.objects.create(
            username='customer',
            password='password',
            first_name='John',
            last_name='Doe'
        )
        customer = Customer.objects.create(
            user=user
        )
        Invoice.objects.create(
            customer=customer,
            amount=100,
            balance=100
        )

    def test_invoice_id(self):
        """Test Invoice.payment_id is of type UUID."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)

        self.assertIsInstance(invoice.invoice_id, uuid.UUID)

    def test_amount_balance_values(self):
        """Test Invoice.amount and Invoice.balance are correct."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)

        self.assertEqual(invoice.amount, 100)
        self.assertEqual(invoice.balance, 100)

    def test_amount_value_above_max(self):
        """Test Invoice.amount above the maximum value fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)

        with self.assertRaises(ValidationError):
            invoice.amount = 100001
            invoice.full_clean()
            invoice.save()

    def test_amount_value_below_min(self):
        """Test Invoice.amount below the minimum value fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)

        with self.assertRaises(ValidationError):
            invoice.amount = -10
            invoice.full_clean()
            invoice.save()

    def test_balance_value_above_max(self):
        """Test Invoice.balance above the maximum value fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)

        with self.assertRaises(ValidationError):
            invoice.balance = 100001
            invoice.full_clean()
            invoice.save()

    def test_balance_value_below_min(self):
        """Test Invoice.balance below the minimum value fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)

        with self.assertRaises(ValidationError):
            invoice.balance = -10
            invoice.full_clean()
            invoice.save()

    def test_amount_lower_than_balance(self):
        """Test Invoice.amount below Invoice.balance fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)

        with self.assertRaises(ValidationError):
            invoice.amount = 50
            invoice.balance = 100
            invoice.save()


class PaymentModelTests(TestCase):
    def setUp(self):
        user = User.objects.create(
            username='customer',
            password='password',
            first_name='John',
            last_name='Doe'
        )
        customer = Customer.objects.create(
            user=user
        )
        invoice = Invoice.objects.create(
            customer=customer,
            amount=100,
            balance=100
        )
        Payment.objects.create(
            customer=customer,
            invoice=invoice,
            payment_id=uuid.uuid4(),
            amount=50
        )

    def test_payment_id(self):
        """Test Payment.payment_id is of type UUID."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)
        payment = Payment.objects.get(invoice=invoice)

        self.assertIsInstance(payment.payment_id, uuid.UUID)

    def test_amount_value(self):
        """Test Payment.amount is correct."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)
        payment = Payment.objects.get(invoice=invoice)

        self.assertEqual(payment.amount, 50)

    def test_amount_value_above_max(self):
        """Test Payment.amount above the maximum value fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)
        payment = Payment.objects.get(invoice=invoice)

        with self.assertRaises(ValidationError):
            payment.amount = 100001
            payment.full_clean()
            payment.save()

    def test_amount_value_above_max(self):
        """Test Payment.amount below the minimum value fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)
        payment = Payment.objects.get(invoice=invoice)

        with self.assertRaises(ValueError):
            payment.amount = -10
            payment.full_clean()
            payment.save()

    def test_amount_value_above_max(self):
        """Test Payment.balance above Payment.amount fails."""
        customer = Customer.objects.get(user__username='customer')
        invoice = Invoice.objects.get(customer=customer)
        payment = Payment.objects.get(invoice=invoice)

        with self.assertRaises(ValidationError):
            payment.amount = 200
            payment.full_clean()
            payment.save()

