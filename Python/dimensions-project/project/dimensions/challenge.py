from django.core.exceptions import ObjectDoesNotExist
from .models import Company, Dimension



def list_children(dimension_id: int=None, company_id: int=None) -> list[str]:
    """List a dimension and all its children in a nested hierarchy.

    dimension_map = {
        1:  'Account',
        2:  'Income Statement',
        3:  'Revenue',
        4:  'Product Revenue',
        5:  'Services Revenue',
        6:  'Expense',
        7:  'Net Income',
        8:  'Balance Sheet',
        9:  'Assets',
        10: 'Liabilities',
        11: 'Equity',
        12: 'Scenario',
        13: 'Actuals',
        14: 'Budget',
        15: 'Department',
        16: 'All Departments',
        17: 'Marketing',
        18: 'Product',
        19: 'Engineering',
        20: 'Design',
        21: 'General & Administrative',
        22: 'Operations',
        23: 'Human Resources',
        24: 'Finance & Accounting',
    }

    hierarchy_map = {
        0:  [1,12,15]
        1:  [2,8],
        2:  [3,6,7],
        3:  [4,5],
        4:  [],
        5:  [],
        6:  [],
        7:  [],
        8:  [9,10,11],
        9:  [],
        10: [],
        11: [],
        12: [13,14],
        13: [],
        14: [],
        15: [16],
        16: [17,18,21],
        17: [],
        18: [19,20],
        19: [],
        20: [],
        21: [22,23,24],
        22: [],
        23: [],
        24: [],
    }
    """
    if dimension_id is None and company_id is None:
        raise ValueError(f"Invalid function arguments dimension_id, company_id: '{dimension_id}', '{company_id}'.")
    if dimension_id and not isinstance(dimension_id, int):
        raise ValueError(f"Invalid dimension_id: '{dimension_id}'. Mus be of type int.")
    if company_id and not isinstance(company_id, int):
        raise ValueError(f"Invalid company_id: '{dimension_id}'. Must be of type int.")


    # validate function arguments
    #
    # dimension_id
    if dimension_id:
        try:
            dimension = Dimension.objects.get(id=dimension_id)
        except ObjectDoesNotExist:
            print(f"Invalid dimension_id: {dimension_id}. Does not exist.")
            return []

        if company_id and company_id != dimension.company_id:
            print(f"Invalid dimension_id: {dimension_id}. Does not match company_id: {company_id}.")
            return []

        # all kosher
        company_id = dimension.company_id

    # company_id
    dimensions = None
    if company_id:
        dimensions = Dimension.objects.filter(company_id=company_id).order_by('id')

        if not dimensions.exists():
            print(f"Invalid company_id: {company_id}. Does not exist.")
            return []


    # build lookup tables
    #
    # dimension_map = {dimension.id: dimension.name,}
    dimension_map = {}

    # hierarchy_map = {parent_id: [child_id,],}
    # assign a dummy parent_id of '0' for top level dimensions
    hierarchy_map = {0: []}

    for dimension in dimensions:
        # id: name
        dimension_map[dimension.id] = dimension.name

        # parent_id: [child_id,]
        hierarchy_map[dimension.id] = []

    for dimension in dimensions:
        if dimension.parent_id:
            # child dimension with a parent
            hierarchy_map[dimension.parent_id].append(dimension.id)
        else:
            # top level dimension with no parent
            hierarchy_map[0].append(dimension.id)

    # sort hierarchy_map children based on dimension.name as we need to return a sorted tree
    for parent, children in hierarchy_map.items():
        children.sort(key=lambda child_id: dimension_map[child_id])


    branch = []
    def traverse_hierarchy(dimension_id: int, level: int) -> list[str]:
        """Recursive traversal of the parent: [child,] hierarchy_map.
        """
        # base case
        if dimension_id is None:
            return branch

        if not isinstance(dimension_id, int) or dimension_id not in hierarchy_map:
            raise ValueError(f"Invalid dimension id: '{dimension_id}'. Must be of type int.")
        if not isinstance(level, int) or level < 0:
            raise ValueError(f"Invalid level: '{level}'. Must be of type int.")

        indent = '\t' * level  # indent for a dimension
        branch.append(f'{indent}{dimension_map[dimension_id]}')

        level += 1  # hierarchy level used for indentation of dimension
        for child_id in hierarchy_map[dimension_id]:
            traverse_hierarchy(child_id, level)

        return branch


    # get a hierarchy branch for dimension_id
    if dimension_id:
        return traverse_hierarchy(dimension_id, 0)

    # get a hierarchy tree (all branches) for company_id
    # pull a hierarchy for all top level dimension ids
    tree = None
    for dimension_id in hierarchy_map[0]:
        tree = traverse_hierarchy(dimension_id, 0)
    return tree



def list_hierarchy(company_id: int) -> list[str]:
    """ List the complete nested hierarchy for a company.
    """
    if not isinstance(company_id, int):
        raise ValueError(f"Invalid company_id: '{company_id}'. Must be of type int.")

    return list_children(None, company_id)


