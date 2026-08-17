from rest_framework.pagination import PageNumberPagination


class ProductPagination(PageNumberPagination):
    """Small catalog pages for incremental web and mobile loading."""

    page_size = 12
    page_size_query_param = "page_size"
    max_page_size = 24
