import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/game/controller.dart';
import 'package:bus_jam/game/engine.dart';
import 'package:bus_jam/platform/durable_analytics.dart';
import 'package:bus_jam/platform/monetization.dart';
import 'package:bus_jam/platform/progress_store.dart';

class BrokenStore implements ProgressStore {
  @override Future<String?> read()async=>null;
  @override Future<void> write(String value)async=>throw StateError('disk full');
}
class ThrowingAds extends OfflineAds {
  @override Future<bool> interstitial()async=>throw StateError('SDK unavailable');
}
class SerialStore extends MemoryProgressStore {
  int active=0,maxActive=0;
  @override Future<void> write(String value)async{active++;if(active>maxActive){maxActive=active;}await Future<void>.delayed(const Duration(milliseconds:2));await super.write(value);active--;}
}
void main(){
 test('BR-38 durable analytics retains first install and days across sessions',()async{
  final s=MemoryProgressStore();final a=DurableAnalytics(s,clock:()=>DateTime(2026,10,6));await a.load();a.track('session_start',{});await a.flush();
  final b=DurableAnalytics(s,clock:()=>DateTime(2026,10,7));await b.load();b.track('level_win',{'level':1});await b.flush();expect(b.firstSeen,DateTime(2026,10,6));expect(b.activeDays.length,2);expect(b.events.length,2);
 });
 test('BR-39 failed saves report error while game remains usable',()async{
  final c=GameController(store:BrokenStore());await c.load();c.settings(sound:false);await c.save();expect(c.saveFailed,true);expect(c.loaded,true);
  expect(c.release(c.level.solution.first).accepted,true);await c.save();
 });
 test('BR-40 racing mutations serialize writes and latest save wins',()async{
  final s=SerialStore();final c=GameController(store:s);await c.load();c.settings(sound:false);c.settings(haptics:false);c.settings(reducedMotion:true);await c.save();
  expect(s.maxActive,1);final r=GameController(store:s);await r.load();expect(r.sound,false);expect(r.haptics,false);expect(r.reducedMotion,true);
 });
 test('BR-41 interstitial exception cannot trap player on win screen',()async{
  final c=GameController(store:MemoryProgressStore(),ads:ThrowingAds());await c.load();c.unlocked=6;c.openLevel(6);c.totalWins=3;
  for(final lane in GameEngine.solve(c.level,c.board)!){c.release(lane);}await c.next();expect(c.level.number,7);expect(c.busy,false);
 });
}
