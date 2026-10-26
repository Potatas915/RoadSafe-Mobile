import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadsafe_mobile/backend/backend.dart';
import 'package:roadsafe_mobile/backend/enforcer.dart';

void main() {
  test(
    'heartbeat has no state payload and duty includes nullable expected station',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final api = EnforcerBackend(RoadSafeBackend(client: client));
      await api.heartbeat();
      await api.duty('way/2', true, expectedStationId: null);
      await api.duty('way/2', false, expectedStationId: 'node/1');
      expect(requests[0].url.path, '/rest/v1/rpc/heartbeat_enforcer');
      expect(jsonDecode(requests[0].body), isNull);
      expect(requests[1].url.path, '/rest/v1/rpc/set_enforcer_duty_checked');
      expect(jsonDecode(requests[1].body), {
        'p_station': 'way/2',
        'p_on_duty': true,
        'p_expected_station_id': null,
      });
      expect(jsonDecode(requests[2].body), {
        'p_station': 'way/2',
        'p_on_duty': false,
        'p_expected_station_id': 'node/1',
      });
    },
  );
}
