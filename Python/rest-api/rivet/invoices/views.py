import uuid
import decimal

from django.contrib.auth.models import User
from django.core.exceptions import ObjectDoesNotExist
from django.db import transaction
from django.db.models import Prefetch
from django.http import QueryDict
from django.shortcuts import get_list_or_404, get_object_or_404

from rest_framework import generics, permissions, serializers, status
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response

from .serializers import InvoiceSerializer, PaymentSerializer, PaymentPostSerializer

from customers.models import Customer
from .models import Invoice, Payment


def get_customer(user: User) -> Customer:
    """Get a costumer matching User else raise PermissionDenied exception."""
    if not isinstance(user, User):
        raise TypeError(f"Argument 'user' must be of type User")

    try:
        customer = Customer.objects.get(user=user)
    except ObjectDoesNotExist:
        raise PermissionDenied(f"User '{user}' is not a customer.")

    return customer


class InvoiceListView(generics.ListAPIView):
    """Methods: GET.

    GET a list of invoices for a customer.
    """
    serializer_class = InvoiceSerializer

    def get_queryset(self) -> 'QuerySet':
        user = self.request.user
        customer = get_customer(user)

        return Invoice.objects.filter(customer=customer)


class InvoiceDetailView(generics.RetrieveUpdateAPIView):
    """Methods: GET, PATCH.

    GET or PATCH a specific customer invoice.
    """
    queryset = Invoice.objects.all()
    serializer_class = InvoiceSerializer

    def get_object(self) -> Invoice:
        """Get an invoice only if its customer is the caller."""
        user = self.request.user
        customer = get_customer(user)
        queryset = self.get_queryset()

        filter = {
            'customer': customer,
            'invoice_id': self.kwargs.get('invoice_id')
        }
        return get_object_or_404(queryset, **filter)

    def patch(self, request: 'Request', *args, **kwargs):
        """PATCH a specific customer invoice."""
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        return Response(serializer.data, status=status.HTTP_200_OK)


class PaymentListView(generics.ListCreateAPIView):
    """Methods: GET, POST.

    GET a list of payments made by a customer.
    Params (not required):
    amount_gte - filters for payment amount greater than or equal to (not required).
    amount_lte - filters for payment amount less than or equal to (not required).
    invoice - filters for payments that have been applied to a specific invoice id (not required).

    Example API call:
    /api/payments/?invoice=0e0f993b-4dac-4331-b7db-a42266bd92bc&amount_gre=50


    POST a payment to one or more customer's invoices.
    Params:
    invoice - invoice id (UUID) (required).
    amount - amount of payment to apply to the remaining balance of the invoice (required).

    Example API call:
    /api/payments/
    payload = [
        {"invoice": "feb7f5a7-cbf0-4f3d-ab3a-b611e03cd1e2", "amount": 50},
        {"invoice": "0e0f993b-4dac-4331-b7db-a42266bd92bc", "amount": 100}
    ]
    """
    serializer_class = PaymentSerializer

    def get_queryset(self) -> 'QuerySet':
        user = self.request.user
        customer = get_customer(user)

        return Payment.objects.filter(customer=customer)

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return PaymentPostSerializer

        return PaymentSerializer

    def get(self, request: 'Request', *args, **kwargs) -> Response:
        """GET a list of payments made by a customer.

        Results can be filtered by amount_gte, amount_lte, invoice.
        """
        queryset = self.get_queryset()

        # Validate params passed in API request
        # amount_gte: int/float
        amount_gte = request.query_params.get('amount_gte')
        if amount_gte:
            amount_gte = float(amount_gte)
            if amount_gte <= 0:
                raise ValidationError("Param 'amount_gte' must be greater than 0.")
            queryset = queryset.filter(amount__gte=amount_gte)

        # amount_lte: int/float
        amount_lte = request.query_params.get('amount_lte')
        if amount_lte:
            amount_lte = float(amount_lte)
            if amount_lte <= 0:
                raise ValidationError("Param 'amount_lte' must be greater than 0.")
            queryset = queryset.filter(amount__lte=amount_lte)

        if amount_gte and amount_lte and amount_gte > amount_lte:
            raise ValidationError("Param 'amount_gte' must be less than or equal to amount_lte.")

        # invoice: UUID
        invoice_id = request.query_params.get('invoice')
        if invoice_id:
            invoice = get_object_or_404(Invoice, invoice_id=invoice_id)
            queryset = queryset.filter(invoice=invoice)

        page = self.paginate_queryset(queryset)
        if page:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    def post(self, request: 'Request', *args, **kwargs) -> Response:
        """POST a payment to one or more customer invoices.

        payload = [
            {"invoice": "feb7f5a7-cbf0-4f3d-ab3a-b611e03cd1e2", "amount": 50},
            {"invoice": "0e0f993b-4dac-4331-b7db-a42266bd92bc", "amount": 100}
        ]
        """
        user = request.user
        customer = get_customer(user)
        payment_id = uuid.uuid4()
        request_data = request.data.copy()

        # Wrap the payload in a list if we just got a single dict param
        if isinstance(request_data, dict):
            request_data = [request_data]

        # Validate params passed in API request
        for item in request_data:
            if 'invoice' not in item:
                raise ValidationError("Param 'invoice' is required.")
            # Replace invoice_id with corresponding object.id
            # invoice: UUID string or pk of object (from serializer)
            invoice = get_object_or_404(Invoice, customer=customer, invoice_id=item['invoice'])
            item['invoice'] = invoice.id

            if 'amount' not in item:
                raise ValidationError("Param 'amount' is required.")

            item['amount'] = decimal.Decimal(item['amount']).quantize(decimal.Decimal('0.01'))

            if item['amount'] < 0.01:
                raise ValidationError("Param 'amount' must be greater than 0.")

            if item['amount'] > invoice.balance:
                raise ValidationError(
                    f'Unable to apply a payment in the amount of {item["amount"]} to the invoice {invoice.invoice_id}. ' +
                    f'The payment amount exceeds the invoice balance of {invoice.balance} .'
                )

        # Make sure that either all or none of the payments in this request succeed
        with transaction.atomic():
            serializer = self.get_serializer(data=request_data, many=True)
            serializer.is_valid(raise_exception=True)
            created = serializer.save(
                customer=customer,
                payment_id=payment_id
            )
            serializer = PaymentSerializer(created, many=True)

            return Response(serializer.data, status=status.HTTP_201_CREATED)


class PaymentDetailView(generics.ListAPIView):
    """Methods: GET.

    GET a detailed payment info which could actually be represented by multiple objects (one object per invoice payment).
    """
    serializer_class = PaymentSerializer

    def get_queryset(self) -> 'QuerySet':
        user = self.request.user
        customer = get_customer(user)

        filter = {
            'customer': customer,
            'payment_id': self.kwargs.get('payment_id')
        }
        return get_list_or_404(Payment, **filter)
