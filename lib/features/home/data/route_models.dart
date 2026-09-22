class RouteModel {
  final String id;
  final String routeId;
  final String coverage;
  final String status;
  final double operatorPackages;
  final String type;
  final List<OrderModel> orders;

  RouteModel({
    required this.id,
    required this.routeId,
    required this.coverage,
    this.status = 'PENDIENTE',
    this.operatorPackages = 0.0,
    this.type = '',
    this.orders = const [],
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final id = (json['numeroGuia'] ?? json['numGuia'] ?? json['guia'] ?? json['idRuta'] ?? json['id'] ?? '').toString();
    final routeId = (json['idRoute'] ?? json['routeId'] ?? json['idRuta'] ?? id).toString();
    final origin = (json['iataOrigen'] ?? json['origen'] ?? '').toString().trim();
    final destination = (json['iataDestino'] ?? json['destino'] ?? json['estadoDestino'] ?? '').toString().trim();
    final coverage = origin.isNotEmpty && destination.isNotEmpty
        ? '$origin -> $destination'
        : (
            json['cobertura'] ??
            json['coverage'] ??
            json['iataDestino'] ??
            json['estadoDestino'] ??
            json['ruta'] ??
            json['descripcion'] ??
            json['cliente'] ??
            json['destino'] ??
            routeId
          ).toString();

    return RouteModel(
      id: id,
      routeId: routeId,
      coverage: coverage,
      status: (json['estatusGuia'] ?? json['status'] ?? json['estatus'] ?? 'PENDIENTE').toString(),
      operatorPackages: double.tryParse((json['cantOperador'] ?? '0').toString()) ?? 0.0,
      type: (json['tipoGuia'] ?? json['type'] ?? '').toString(),
      orders: (json['ordenes'] as List? ?? [])
          .map((o) => OrderModel.fromJson(Map<String, dynamic>.from(o)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeId': routeId,
      'coverage': coverage,
      'status': status,
      'operatorPackages': operatorPackages,
      'type': type,
      'ordenes': orders.map((o) => o.toJson()).toList(),
    };
  }

  String searchableText() {
    final orderParts = orders.expand((o) => [
      o.guideNumber,
      o.os,
      o.referenceOr,
      o.ne,
      o.pieces,
      o.scheduledDate,
      o.destinationState,
      o.client,
      o.address,
      o.time,
    ]).toList();
    return [id, routeId, coverage, status, type, ...orderParts].join(' ').toLowerCase();
  }
}

class OrderModel {
  final String guideNumber;
  final String os;
  final String referenceOr;
  final String ne;
  final String pieces;
  final String scheduledDate;
  final String destinationState;
  final String client;
  final String address;
  final String time;

  OrderModel({
    required this.guideNumber,
    required this.os,
    required this.referenceOr,
    required this.ne,
    required this.pieces,
    required this.scheduledDate,
    required this.destinationState,
    required this.client,
    required this.address,
    required this.time,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      guideNumber: (json['numeroGuia'] ?? json['numGuia'] ?? json['guia'] ?? '').toString(),
      os: (json['os'] ?? json['numOs'] ?? json['ordenServicio'] ?? '').toString(),
      ne: (
        json['ne'] ??
        json['NE'] ??
        json['numeroEmbarque'] ??
        json['numEmbarque'] ??
        json['noEmbarque'] ??
        json['numeroEntrega'] ??
        json['notaEntrega'] ??
        ''
      ).toString(),
      referenceOr: (
        json['referenciaOR'] ??
        json['referenciaOr'] ??
        json['referenciaor'] ??
        json['ReferenciaOR'] ??
        json['ReferenciaOr'] ??
        json['referenceOr'] ??
        json['referenceor'] ??
        ''
      ).toString(),
      pieces: (json['ppza'] ?? json['pPza'] ?? json['piezas'] ?? json['cantidadPiezas'] ?? '').toString(),
      scheduledDate: (json['fechaProgramada'] ?? json['fecha_programada'] ?? json['programDate'] ?? json['fecha'] ?? '').toString(),
      destinationState: (json['estadoDestino'] ?? json['destinoEstado'] ?? json['estado'] ?? '').toString(),
      client: (json['clienteDestino'] ?? json['cliente'] ?? json['destino'] ?? '').toString(),
      address: (json['direccDestino'] ?? json['direccion'] ?? json['domicilio'] ?? '').toString(),
      time: (json['horaCompromiso'] ?? json['hora'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numeroGuia': guideNumber,
      'os': os,
      'referenciaOR': referenceOr,
      'ne': ne,
      'ppza': pieces,
      'fechaProgramada': scheduledDate,
      'estadoDestino': destinationState,
      'clienteDestino': client,
      'direccDestino': address,
      'horaCompromiso': time,
    };
  }
}
class RoutePaginatedResponse {
  final List<RouteModel> routes;
  final int totalCount;

  RoutePaginatedResponse({
    required this.routes,
    required this.totalCount,
  });
}
