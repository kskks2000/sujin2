from fastapi import APIRouter, Depends

from app.api.deps import get_current_auth_context
from app.api.routes import allocations, auth, dashboard, dispatches, load_plans, masters, orders, shipments

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(
    dashboard.router,
    prefix="/dashboard",
    tags=["dashboard"],
    dependencies=[Depends(get_current_auth_context)],
)
api_router.include_router(
    orders.router,
    prefix="/orders",
    tags=["orders"],
    dependencies=[Depends(get_current_auth_context)],
)
api_router.include_router(
    shipments.router,
    prefix="/shipments",
    tags=["shipments"],
    dependencies=[Depends(get_current_auth_context)],
)
api_router.include_router(
    load_plans.router,
    prefix="/load-plans",
    tags=["load-plans"],
    dependencies=[Depends(get_current_auth_context)],
)
api_router.include_router(
    allocations.router,
    prefix="/allocations",
    tags=["allocations"],
    dependencies=[Depends(get_current_auth_context)],
)
api_router.include_router(
    dispatches.router,
    prefix="/dispatches",
    tags=["dispatches"],
    dependencies=[Depends(get_current_auth_context)],
)
api_router.include_router(
    masters.router,
    prefix="/masters",
    tags=["masters"],
    dependencies=[Depends(get_current_auth_context)],
)
