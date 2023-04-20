import uuid

from django.urls import reverse
from django.core.exceptions import ValidationError

from rest_framework import status
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError

from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from django.contrib.auth.models import User
from customers.models import Customer
from invoices.models import Invoice, Payment


class InvoiceAPITests(APITestCase):
    def setUp(self):
        """Populate test databate with test Users, Customers, and Invoices"""
        self.domain = 'http://localhost:8000'
        self.persons = [
            {
                'username': 'bobdylan',
                'password': 'bobdylanpassword',
                'email': 'bob.dylan@gmail.com',
                'first_name': 'Bob',
                'last_name': 'Dylan'
            },
            {
                'username': 'johnlennon',
                'password': 'johnlennonpassword',
                'email': 'john.lennon@gmail.com',
                'first_name': 'John',
                'last_name': 'Lennon'
            },
            {
                'username': 'tomwaits',
                'password': 'tomwaitspassword',
                'email': 'tom.waits@gmail.com',
                'first_name': 'Tom',
                'last_name': 'Waits'
            }
        ]
        # 21 values
        self.values = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105]

        for person in self.persons:
            # Create one User/Customer per person
            username = person['username']
            password = person['password']
            email = person['email']
            first_name = person['first_name']
            last_name = person['last_name']

            user = User.objects.create(
                username=username,
                password=password,
                email=email,
                first_name=first_name,
                last_name=last_name
            )
            customer = Customer.objects.create(
                user=user
            )
            # Create 21 invoices per Customer
            # The large number of invoices will allow us to test pagination
            for value in self.values:
                Invoice.objects.create(
                    customer=customer,
                    amount=value,
                    balance=value
                )

    def test_get_customer(self):
        """Ensure the helper method works as expected.

        get_customer(user: User) -> Customer
        """
        from invoices.views import get_customer

        with self.assertRaises(TypeError):
            # Argument type incorrect
            get_customer(str())

        user_not_customer = User.objects.create(
            username='user_not_customer',
            password='user_not_customer_password',
            email='user_not_customer@gmail.com',
            first_name='FirstName',
            last_name='LastName'
        )
        with self.assertRaises(PermissionDenied):
            # Argument type correct, but the user is not a customer
            get_customer(user_not_customer)

        user_is_customer = User.objects.get(username=self.persons[0]['username'])
        self.assertIsInstance(
            get_customer(user_is_customer),
            Customer,
            'Incorrect type returned.'
        )

    def test_get_invoice_list(self):
        """Ensure GET retrieves a list of customer invoices."""

        for person in self.persons:
            user = User.objects.get(username=person['username'])
            self.client.force_authenticate(user=user)

            # invoice QuerySet ordering is set on the model (-created)
            # so we'll need to iterate over values in revers order
            i = len(self.values)

            url = self.domain + reverse('invoice-list')
            while url:
                page_size = 10 if i >= 10 else i

                response = self.client.get(url, format='json')

                self.assertEqual(
                    response.status_code,
                    status.HTTP_200_OK,
                    'Expected a successful GET request.'
                )
                self.assertEqual(
                    response.data['count'],
                    len(self.values),
                    'Incorrect number of invoices returned.'
                )
                self.assertEqual(
                    len(response.data['results']),
                    page_size,
                    'Incorrect number of paginated invoices returned.'
                )

                for invoice in response.data['results']:
                    i -= 1
                    amount = self.values[i]
                    balance = self.values[i]

                    self.assertEqual(
                        invoice['customer_full_name'],
                        person['first_name'] + ' ' + person['last_name'],
                        'Incorrect value for Invoice.full_name.'
                    )
                    self.assertIsInstance(
                        uuid.UUID(invoice['customer_id']),
                        uuid.UUID,
                        'Invalid value for Invoice.customer_id.'
                    )
                    self.assertIsInstance(
                        uuid.UUID(invoice['invoice_id']),
                        uuid.UUID,
                        'Invalid value for Invoice.invoice_id.'
                    )
                    self.assertEqual(
                        float(invoice['amount']),
                        amount,
                        'Incorrect value for Invoice.amount.'
                    )
                    self.assertEqual(
                        float(invoice['balance']),
                        balance,
                        'Incorrect value for Invoice.balance.'
                    )

                # get next page of paginated list of invoices
                url = response.data.get('next')

    def test_get_invoice_detail(self):
        """Ensure GET retreives a detailed invoice."""
        user = User.objects.get(username=self.persons[0]['username'])
        customer = Customer.objects.get(user=user)
        invoice = Invoice.objects.filter(customer=customer).first()
        invoice_id = invoice.invoice_id

        self.client.force_authenticate(user=user)

        # Invoice in DB
        url = self.domain + reverse('invoice-detail', args=[invoice_id])
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
            'Expected a successful GET request.'
        )
        self.assertEqual(
            uuid.UUID(response.data['invoice_id']),
            invoice.invoice_id,
            'Invalid value for Invoice.invoice_id.'
        )

        # Invoice not in DB
        invoice_id = uuid.uuid4()
        url = self.domain + reverse('invoice-detail', args=[invoice_id])
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
            'Expected a failed GET request.'
        )

    def test_patch_invoice_detail(self):
        """Ensure PATCH updates invoices as expected."""
        user = User.objects.get(username=self.persons[0]['username'])
        customer = Customer.objects.get(user=user)
        invoice = Invoice.objects.filter(customer=customer).first()
        invoice_id = invoice.invoice_id

        self.client.force_authenticate(user=user)

        # Invoice in DB, update Invoice.amount and Invoice.balance
        data = {
            'amount': '200.00',
            'balance': '20.00'
        }
        url = self.domain + reverse('invoice-detail', args=[invoice_id])
        response = self.client.patch(url, data, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
            'Expected a successful PATCH request.'
        )
        self.assertEqual(
            uuid.UUID(response.data['invoice_id']),
            invoice_id,
            'Invalid value for Invoice.invoice_id.'
        )
        self.assertEqual(
            response.data['amount'],
            data['amount'],
            'PATCH failed to update Invoice.amount'
        )
        self.assertEqual(
            response.data['balance'],
            data['balance'],
            'PATCH failed to update Invoice.balance'
        )

        # Invoice in DB, Invoice.balance > Invoice.amount
        data = {
            'amount': '20.00',
            'balance': '100.00'
        }
        url = self.domain + reverse('invoice-detail', args=[invoice_id])
        response = self.client.patch(url, data, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
            'Expected a failed PATCH request.'
        )

        # Invoice in DB, invalid Invoice.amount
        data = {
            'amount': '-20.00',
        }
        url = self.domain + reverse('invoice-detail', args=[invoice_id])
        response = self.client.patch(url, data, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
            'Expected a failed PATCH request.'
        )

        # Invoice in DB, invalid Invoice.balance
        data = {
            'balance': '-20.00',
        }
        url = self.domain + reverse('invoice-detail', args=[invoice_id])
        response = self.client.patch(url, data, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
            'Expected a failed PATCH request.'
        )

        # Invoice not in DB
        invoice_id = uuid.uuid4()
        url = self.domain + reverse('invoice-detail', args=[invoice_id])
        response = self.client.patch(url, data, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
            'Expected a failed PATCH request.'
        )


class PaymentAPITests(APITestCase):
    def setUp(self):
        """Populate test databate with test Users, Customers, Invoices, and Payments."""
        self.domain = 'http://localhost:8000'
        self.persons = [
            {
                'username': 'bobdylan',
                'password': 'bobdylanpassword',
                'email': 'bob.dylan@gmail.com',
                'first_name': 'Bob',
                'last_name': 'Dylan'
            },
            {
                'username': 'johnlennon',
                'password': 'johnlennonpassword',
                'email': 'john.lennon@gmail.com',
                'first_name': 'John',
                'last_name': 'Lennon'
            },
            {
                'username': 'tomwaits',
                'password': 'tomwaitspassword',
                'email': 'tom.waits@gmail.com',
                'first_name': 'Tom',
                'last_name': 'Waits'
            }
        ]
        # 21 values
        self.values = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105]

        for i, person in enumerate(self.persons):
            # Create one User/Customer per person
            username = person['username']
            password = person['password']
            email = person['email']
            first_name = person['first_name']
            last_name = person['last_name']

            user = User.objects.create(
                username=username,
                password=password,
                email=email,
                first_name=first_name,
                last_name=last_name
            )
            customer = Customer.objects.create(
                user=user
            )
            # Create 21 invoices and 21 payments per Customer
            # The large number of invoices and payments will allow us to test pagination
            for value in self.values:
                invoice = Invoice.objects.create(
                    customer=customer,
                    amount=value,
                    balance=value
                )
                Payment.objects.create(
                    customer=customer,
                    invoice=invoice,
                    payment_id=uuid.uuid4(),
                    amount=value-5,
                )

    def test_get_payment_list(self):
        """Ensure GET retrieves a list of customer payments."""

        for person in self.persons:
            user = User.objects.get(username=person['username'])
            self.client.force_authenticate(user=user)

            # invoice QuerySet ordering is set on the model (-created)
            # so we'll need to iterate over values in revers order
            i = len(self.values)

            url = self.domain + reverse('payment-list')
            while url:
                page_size = 10 if i >= 10 else i

                response = self.client.get(url, format='json')

                self.assertEqual(
                    response.status_code,
                    status.HTTP_200_OK,
                    'Expected a successful GET request.'
                )
                self.assertEqual(
                    response.data['count'],
                    len(self.values),
                    'Incorrect number of invoices returned.'
                )
                self.assertEqual(
                    len(response.data['results']),
                    page_size,
                    'Incorrect number of paginated payments returned.'
                )

                for payment in response.data['results']:
                    i -= 1
                    payment_amount = self.values[i] - 5
                    invoice_amount = self.values[i]
                    invoice_balance = 5

                    self.assertEqual(
                        payment['customer_full_name'],
                        person['first_name'] + ' ' + person['last_name'],
                        'Incorrect value for Payment.full_name.'
                    )
                    self.assertIsInstance(
                        uuid.UUID(payment['customer_id']),
                        uuid.UUID,
                        'Invalid value for Payment.customer_id.'
                    )
                    self.assertIsInstance(
                        uuid.UUID(payment['invoice_id']),
                        uuid.UUID,
                        'Invalid value for Payment.invoice_id.'
                    )
                    self.assertEqual(
                        float(payment['amount']),
                        payment_amount,
                        'Incorrect value for Payment.amount.'
                    )

                    invoice = Invoice.objects.get(invoice_id=payment['invoice_id'])
                    self.assertEqual(
                        invoice.amount,
                        invoice_amount,
                        'Incorrect value for Invoice.amount.'
                    )
                    self.assertEqual(
                        invoice.balance,
                        invoice_balance,
                        'Incorrect value for Invoice.balance.'
                    )

                # get next page of paginated list of invoices
                url = response.data.get('next')

    def test_get_payment_list_by_param(self):
        """Ensure GET retreives a list of customer payments based on givern params."""
        user = User.objects.get(username=self.persons[0]['username'])
        customer = Customer.objects.get(user=user)
        invoice = Invoice.objects.filter(customer=customer).first()

        self.client.force_authenticate(user=user)

        # Get all payments for a specific invoice_id (invoice=UUID)
        url = self.domain + reverse('payment-list') + '?invoice=' + str(invoice.invoice_id)
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
            'Expected a successful GET request.'
        )
        self.assertEqual(
            response.data['count'],
            1,
            'Incorrect number of payments returned.'
        )

        # Get all payments where payment amount >= 45 (amount_gte=45)
        url = self.domain + reverse('payment-list') + '?amount_gte=45'
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
            'Expected a successful GET request.'
        )

        num_of_payments = 0
        for value in sorted(self.values):
            payment_amount = value - 5
            if payment_amount >= 45:
                num_of_payments += 1

        self.assertEqual(
            response.data['count'],
            num_of_payments,
            'Incorrect number of payments returned.'
        )

        # Get all payments where payment amount <= 55 (amount_lte=55)
        url = self.domain + reverse('payment-list') + '?amount_lte=55'
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
            'Expected a successful GET request.'
        )

        num_of_payments = 0
        for value in sorted(self.values):
            payment_amount = value - 5
            if payment_amount > 55:
                break
            num_of_payments += 1

        self.assertEqual(
            response.data['count'],
            num_of_payments,
            'Incorrect number of payments returned.'
        )

        # Get all payments where payment amount >= 30 and amount <= 60 (amount_gte=30&amount_lte=60)
        url = self.domain + reverse('payment-list') + '?amount_gte=30&amount_lte=60'
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
            'Expected a successful GET request.'
        )

        num_of_payments = 0
        for value in sorted(self.values):
            payment_amount = value - 5
            if payment_amount > 60:
                break
            if payment_amount >= 30:
                num_of_payments += 1

        self.assertEqual(
            response.data['count'],
            num_of_payments,
            'Incorrect number of payments returned.'
        )

        # Test invalid params range, amount >= 60 and amount <= 30 (amount_gte=60&amount_lte=30)
        url = self.domain + reverse('payment-list') + '?amount_gte=60&amount_lte=30'
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
            'Expected a failed GET request.'
        )


    def test_get_payment_detail(self):
        """Ensure GET retrieves a detailed payment."""
        user = User.objects.get(username=self.persons[0]['username'])
        customer = Customer.objects.get(user=user)
        payment = Payment.objects.filter(customer=customer).first()
        payment_id = payment.payment_id

        self.client.force_authenticate(user=user)

        # Payment in DB
        url = self.domain + reverse('payment-detail', args=[payment_id])
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
            'Expected a successful GET request.'
        )
        for payment in response.data['results']:
            self.assertEqual(
                uuid.UUID(payment['payment_id']),
                payment_id,
                'Invalid value for Payment.payment_id.'
            )

        # Payment not in DB
        payment_id = uuid.uuid4()
        url = self.domain + reverse('payment-detail', args=[payment_id])
        response = self.client.get(url, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
            'Expected a failed GET request.'
        )

    def test_post_payment(self):
        """Ensure POST creates payments as expected."""
        user = User.objects.get(username=self.persons[0]['username'])
        customer = Customer.objects.get(user=user)
        invoice = Invoice.objects.filter(customer=customer).first()
        invoice_id = invoice.invoice_id
        invoice_amount = invoice.amount
        invoice_balance = invoice.balance

        self.client.force_authenticate(user=user)

        # Post a payment to a single invoice
        data = {
            'invoice': invoice_id,
            'amount': '5.00',
        }
        url = self.domain + reverse('payment-list')
        response = self.client.post(url, data, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
            'Expected a successful POST request.'
        )

        for payment in response.data:
            self.assertEqual(
                uuid.UUID(payment['invoice_id']),
                invoice_id,
                'Invalid value for Invoice.invoice_id.'
            )
            self.assertEqual(
                payment['amount'],
                '5.00',
                'POST failed to update Invoice.amount'
            )

        invoice.refresh_from_db()
        self.assertEqual(
            invoice.amount,
            invoice_amount,
            'POST modified Invoice.amount'
        )
        self.assertEqual(
            invoice.balance,
            invoice_balance - 5,
            'POST failed to update Invoice.balance'
        )

        # Post a payment to multiple invoices in one API call
        payments = []
        invoices = Invoice.objects.filter(customer=customer)
        for invoice in invoices:
            if invoice.balance < 5:
                continue
            payment = {
                'invoice': str(invoice.invoice_id),
                'amount': '5.00',
            }
            payments.append(payment)

        url = self.domain + reverse('payment-list')
        response = self.client.post(url, payments, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
            'Expected a successful POST request.'
        )
        self.assertEqual(
            len(response.data),
            len(payments),
            'Incorrect number of payments created.'
        )

        payment_id = None
        for payment in response.data:
            if not payment_id:
                payment_id = payment['payment_id']

            self.assertEqual(
                payment['payment_id'],
                payment_id,
                'Invalid value for Payment.payment_id.'
            )
            self.assertEqual(
                payment['amount'],
                '5.00',
                'POST failed to update Invoice.amount'
            )

        # Post a payment to an invalid invoice
        payment = {
            'invoice': str(uuid.uuid4()),
            'amount': '5.00',
        }

        url = self.domain + reverse('payment-list')
        response = self.client.post(url, payment, format='json')

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
            'Expected a failed POST request.'
        )



