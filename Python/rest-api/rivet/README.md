Design
=======================
The REST API is implemented using Django/DjangoRestFramework with two Django apps:
1. customers - manages valid customers who can have invoices assign to them and make payments on those invoices.
2. invoices - manages customers' invoices and payments.


Docker
=======================
The project has been dockerized (Dockerfile). Run the following commands to build the project image and run its container. 

    $ cd take-home-assignment/rivet

    $ docker build -t rivet-rest-api .

    $ docker run -ti -p 8000:8000 rivet-rest-api


API Endpoints
=======================

    api/token/ - retrieves an authentication token for a user. If the user is also a customer then you can make API calls to the remaining API endpoints.

    api/invoices/ - retrieves a paginated list of a customer's invoices.

    api/invoices/<invoice_id>/ - retrieves detailed information for a customer's invoice.

    api/payments/ - retrieves a paginated list of a customer's payments.

    api/payments/<payment_id>/ - retrieves detailed information for a customer's payment.


Admin Access
=======================
The Django Admin can be accessed with the following credentials:

    URL: http://localhost:8000/admin

    Username: admin

    Password: password


Database
=======================
The SQLite DB has been populated with some test data to allow for manual API testing. The following users have been created:


Users who are also Customers.

    Jane Doe

    Username: jane.doe

    Password: 123456jd


    John Doe

    Username: john.doe

    Password: 123456jd


    Tom Doe

    Username: tom.doe

    Password: 123456td


Users who are not Customers.

    John Lennon

    Username: john.lennon

    Password: 123456jl


    Michael Jordan

    Username: michael.jordan

    Password: 123456mj


Testing
=======================
The testing can be conducted with:

1. The automated test suite which consists of unit tests for the project models (customers | invoices/tests/test_models.py) 
as well as tests for the REST API (invoices/tests/test_views.py). To execute the entire test suite run the following command:


    $ python manage.py test


2. Web browser by loging in to one of the API endpoints as a valid customer, eg:


    http://localhost:8000/api/invoices/


3. Command Line Interface. To test the API from a CLI you will first need to obtain a user's authentication token to use 
it in subsequent API calls, eg:


    $ curl -X POST -H "Content-Type: application/json" -d '{"username": "tom.doe", "password": "123456td"}' http://localhost:8000/api/token/
    
    {"token":"c3a272b0c28602b0f64e97b227c16375b1424e2f"}

    $ curl -X GET  -H "Content-Type: application/json" http://localhost:8000/api/invoices/ -H 'Authorization: Token c3a272b0c28602b0f64e97b227c16375b1424e2f'
