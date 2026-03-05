import io
import logging
import os
import sys
import traceback
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from .core.config import settings
from .core.database import async_session
from .api.v1.auth import router as auth_router
from .api.v1.users import router as users_router
from .api.v1.households import router as households_router
from .api.v1.chores import router as chores_router
from .api.v1.calendar import router as calendar_router
from .api.v1.grocery import router as grocery_router
from .api.v1.comments import router as comments_router
from .api.v1.meals import router as meals_router
from .api.v1.approvals import router as approvals_router
from .api.v1.notifications import router as notifications_router
from .api.v1.notifications import ws_router as ws_notifications_router
from .api.v1.inventory import router as inventory_router
from .api.v1.ai import router as ai_router

# Force UTF-8 for log output on Windows (Qwen responses may contain emoji)
if sys.stderr.encoding != "utf-8":
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

logging.basicConfig(level=logging.DEBUG)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure upload directory exists
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    # Expose async_session factory on app state for WebSocket handlers
    app.state.db_session = async_session
    yield
    # Shutdown


app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    lifespan=lifespan,
    debug=True,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files for uploads
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# API routes
app.include_router(auth_router, prefix=settings.API_V1_PREFIX)
app.include_router(users_router, prefix=settings.API_V1_PREFIX)
app.include_router(households_router, prefix=settings.API_V1_PREFIX)
app.include_router(chores_router, prefix=settings.API_V1_PREFIX)
app.include_router(calendar_router, prefix=settings.API_V1_PREFIX)
app.include_router(grocery_router, prefix=settings.API_V1_PREFIX)
app.include_router(comments_router, prefix=settings.API_V1_PREFIX)
app.include_router(meals_router, prefix=settings.API_V1_PREFIX)
app.include_router(approvals_router, prefix=settings.API_V1_PREFIX)
app.include_router(notifications_router, prefix=settings.API_V1_PREFIX)
app.include_router(inventory_router, prefix=settings.API_V1_PREFIX)
app.include_router(ai_router, prefix=settings.API_V1_PREFIX)
# WebSocket router at root (no /api/v1 prefix)
app.include_router(ws_notifications_router)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    tb = traceback.format_exception(type(exc), exc, exc.__traceback__)
    logging.error("Unhandled exception:\n" + "".join(tb))
    return JSONResponse(status_code=500, content={"detail": str(exc), "traceback": "".join(tb)})


@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "0.1.0"}
