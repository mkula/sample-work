from django.urls import path
from . import views

urlpatterns = [
    path('api/invoices/', views.InvoiceListView.as_view(), name='invoice-list'),
    path('api/invoices/<uuid:invoice_id>/', views.InvoiceDetailView.as_view(), name='invoice-detail'),
    path('api/payments/', views.PaymentListView.as_view(), name='payment-list'),
    path('api/payments/<uuid:payment_id>/', views.PaymentDetailView.as_view(), name='payment-detail'),
]
