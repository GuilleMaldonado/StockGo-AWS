from datetime import datetime, timezone

from sqlalchemy import (BigInteger, Boolean, CheckConstraint, DateTime, ForeignKey,
                        ForeignKeyConstraint, Identity, Index, Integer, LargeBinary,
                        Numeric, String, Text, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def utcnow():
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Business(Base):
    __tablename__ = 'businesses'
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    normalized_name: Mapped[str] = mapped_column(String(100), unique=True)
    products_version: Mapped[int] = mapped_column(BigInteger, default=0)
    sales_version: Mapped[int] = mapped_column(BigInteger, default=0)
    users_version: Mapped[int] = mapped_column(BigInteger, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class BusinessRequest(Base):
    __tablename__ = 'business_requests'
    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    normalized_name: Mapped[str] = mapped_column(String(100), unique=True)
    usuario: Mapped[str] = mapped_column(String(40))
    nombres: Mapped[str] = mapped_column(String(80))
    apellidos: Mapped[str] = mapped_column(String(80))
    password_hash: Mapped[str] = mapped_column(String(128))
    salt: Mapped[str] = mapped_column(String(128))
    estado: Mapped[str] = mapped_column(String(16), default='pendiente')
    creado: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    resuelto: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    __table_args__ = (CheckConstraint("estado IN ('pendiente','aprobada','rechazada')"), Index('ix_business_requests_estado', 'estado', 'id'))


class User(Base):
    __tablename__ = 'users'
    __table_args__ = (UniqueConstraint('business_id', 'id'), UniqueConstraint('business_id', 'nombre'),
                     UniqueConstraint('business_id', 'codigoInterno'), CheckConstraint("rol IN ('administrador','vendedor')"))
    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    business_id: Mapped[str] = mapped_column(ForeignKey('businesses.id'), index=True)
    nombre: Mapped[str] = mapped_column(String(40))
    password_hash: Mapped[str] = mapped_column(String(128))
    salt: Mapped[str] = mapped_column(String(128))
    rol: Mapped[str] = mapped_column(String(20))
    nombres: Mapped[str] = mapped_column(String(80), default='')
    apellidos: Mapped[str] = mapped_column(String(80), default='')
    codigoInterno: Mapped[str] = mapped_column(String(40))
    versionCredencial: Mapped[int] = mapped_column(Integer, default=0)
    requiereCambioPassword: Mapped[bool] = mapped_column(Boolean, default=False)
    temporalHasta: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class VendorRequest(Base):
    __tablename__ = 'vendor_requests'
    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    business_id: Mapped[str] = mapped_column(ForeignKey('businesses.id'), index=True)
    usuario: Mapped[str] = mapped_column(String(40))
    nombres: Mapped[str] = mapped_column(String(80))
    apellidos: Mapped[str] = mapped_column(String(80))
    password_hash: Mapped[str] = mapped_column(String(128))
    salt: Mapped[str] = mapped_column(String(128))
    estado: Mapped[str] = mapped_column(String(16), default='pendiente')
    creado: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    resuelto: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    __table_args__ = (UniqueConstraint('business_id', 'usuario'), CheckConstraint("estado IN ('pendiente','aprobada','rechazada')"), Index('ix_vendor_requests_estado', 'business_id', 'estado', 'id'))


class Product(Base):
    __tablename__ = 'products'
    __table_args__ = (UniqueConstraint('business_id', 'id'), UniqueConstraint('business_id', 'codigo'),
                     CheckConstraint('cantidad >= 0 AND "stockMinimo" >= 0'),
                     CheckConstraint('precio >= costo AND costo >= 0'),
                     CheckConstraint("categoria IN ('Repuesto','Lubricante','Filtro','Aditivo','Accesorio')"),
                     Index('ix_product_catalog', 'business_id', 'activo', 'id'))
    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    business_id: Mapped[str] = mapped_column(ForeignKey('businesses.id'), index=True)
    nombre: Mapped[str] = mapped_column(String(100))
    codigo: Mapped[str] = mapped_column(String(50))
    precio: Mapped[float] = mapped_column(Numeric(12, 2))
    costo: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    cantidad: Mapped[int] = mapped_column(Integer)
    stockMinimo: Mapped[int] = mapped_column(Integer, default=0)
    activo: Mapped[bool] = mapped_column(Boolean, default=True)
    categoria: Mapped[str] = mapped_column(String(20))
    ficha: Mapped[dict] = mapped_column(JSONB, default=dict)
    imagen: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    thumbnail: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)


class Sale(Base):
    __tablename__ = 'sales'
    __table_args__ = (UniqueConstraint('business_id', 'id'), UniqueConstraint('business_id', 'solicitud'),
                     ForeignKeyConstraint(['business_id', 'usuarioId'], ['users.business_id', 'users.id']),
                     CheckConstraint('"totalCentavos" > 0 AND "totalCentavos" <= 9007199254740991'),
                     CheckConstraint("estado IN ('confirmada','anulada')"),
                     Index('ix_sales_business_user', 'business_id', 'usuarioId', 'id'))
    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    business_id: Mapped[str] = mapped_column(ForeignKey('businesses.id'))
    solicitud: Mapped[str] = mapped_column(String(80))
    usuarioId: Mapped[int] = mapped_column(BigInteger)
    vendedor: Mapped[str] = mapped_column(String(170))
    codigoVendedor: Mapped[str] = mapped_column(String(40))
    fecha: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    totalCentavos: Mapped[int] = mapped_column(BigInteger)
    cliente: Mapped[dict] = mapped_column(JSONB, default=dict)
    estado: Mapped[str] = mapped_column(String(20), default='confirmada')
    anuladaPor: Mapped[str | None] = mapped_column(String(170), nullable=True)
    anuladaFecha: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    motivoAnulacion: Mapped[str] = mapped_column(String(500), default='')


class SaleDetail(Base):
    __tablename__ = 'sale_details'
    __table_args__ = (ForeignKeyConstraint(['business_id', 'ventaId'], ['sales.business_id', 'sales.id']),
                     ForeignKeyConstraint(['business_id', 'productoId'], ['products.business_id', 'products.id']),
                     CheckConstraint('cantidad > 0 AND "precioCentavos" > 0 AND "costoCentavos" >= 0'))
    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    business_id: Mapped[str] = mapped_column(ForeignKey('businesses.id'), index=True)
    ventaId: Mapped[int] = mapped_column(BigInteger, index=True)
    productoId: Mapped[int] = mapped_column(BigInteger)
    nombre: Mapped[str] = mapped_column(String(100))
    codigo: Mapped[str] = mapped_column(String(50))
    lote: Mapped[str] = mapped_column(String(100))
    vencimiento: Mapped[str] = mapped_column(String(10))
    unidad: Mapped[str] = mapped_column(String(2000))
    cantidad: Mapped[int] = mapped_column(Integer)
    precioCentavos: Mapped[int] = mapped_column(BigInteger)
    costoCentavos: Mapped[int] = mapped_column(BigInteger)
    product_snapshot: Mapped[dict] = mapped_column(JSONB, default=dict)


class AuthSession(Base):
    __tablename__ = 'auth_sessions'
    __table_args__ = (ForeignKeyConstraint(['business_id', 'user_id'], ['users.business_id', 'users.id']),)
    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    business_id: Mapped[str] = mapped_column(ForeignKey('businesses.id'), index=True)
    user_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True, index=True)
    credential_version: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class Audit(Base):
    __tablename__ = 'security_audit'
    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    business_id: Mapped[str] = mapped_column(ForeignKey('businesses.id'), index=True)
    fecha: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    actorId: Mapped[int] = mapped_column(BigInteger)
    actor: Mapped[str] = mapped_column(String(170))
    objetivoId: Mapped[int] = mapped_column(BigInteger)
    objetivo: Mapped[str] = mapped_column(String(80))
    accion: Mapped[str] = mapped_column(String(40))


class RateLimit(Base):
    __tablename__ = 'rate_limits'
    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    hits: Mapped[int] = mapped_column(Integer)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
