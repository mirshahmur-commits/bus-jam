/// Authored lessons. Letters represent routes, digits represent seat counts.
/// Queue order, blocking chains and capacities are deliberate puzzle content.
class RoutePlan {
  const RoutePlan(
    this.title,
    this.lesson,
    this.lanes,
    this.queue, {
    this.hard = false,
  });
  final String title, lesson, queue;
  final List<String> lanes;
  final bool hard;
}

const campaign = <RoutePlan>[
  RoutePlan(
    'First departure',
    'Match the first passenger. A full bus leaves.',
    ['a3', 'b3', ''],
    'a3 b3',
  ),
  RoutePlan(
    'Clear the exit',
    'The bus behind becomes available when the front one moves.',
    ['a3 b3', 'c3', ''],
    'b3 a3 c3',
  ),
  RoutePlan(
    'Together',
    'Two partly filled buses can clear the queue together.',
    ['a3', 'b3', 'c3'],
    'a1 b1 a1 b1 a1 b1 c3',
  ),
  RoutePlan(
    'Save the last space',
    'Look behind the front buses before using a parking space.',
    ['a3 c3 b3', 'd3', ''],
    'b3 a3 c3 d3',
    hard: true,
  ),
  RoutePlan(
    'Two exits',
    'Free the route you need first. The other exit can wait.',
    ['a3 b3', 'c3 d3', 'e3'],
    'b3 a3 d3 c3 e3',
  ),
  RoutePlan('Open road', 'A short route. Keep the terminal clear.', [
    'a3 b3',
    'c3',
    '',
  ], 'a3 b3 c3'),
  RoutePlan(
    'Crossed queues',
    'A bus can wait partly full. Keep room for its partner.',
    ['a3 c3', 'b3 d3', 'e3'],
    'c1 a1 c1 a1 c1 a1 d3 b3 e3',
  ),
  RoutePlan(
    'Wrong turn',
    'A future route can block the bus needed right now.',
    ['a3 b3 c3', 'd3 e3', 'f3'],
    'c3 b3 a3 e3 d3 f3',
    hard: true,
  ),
  RoutePlan(
    'One space left',
    'Leave the final space for the bus that unlocks boarding.',
    ['a3 b3', 'c3 d3', 'e3 f3'],
    'b3 a3 d1 c1 d2 c2 e3 f3',
  ),
  RoutePlan('Harbour run', 'Watch the departures and enjoy the flow.', [
    'a3 b3',
    'c3 d3',
    '',
  ], 'a3 c3 b3 d3'),
  RoutePlan(
    'The long way',
    'Plan two releases ahead.',
    ['a3 b3 c3', 'd3 e3', 'f3'],
    'c2 b2 a2 c1 b1 a1 e3 d3 f3',
    hard: true,
  ),
  RoutePlan('Room to breathe', 'Do not park every available bus at once.', [
    'a3 b3',
    'c3 d3',
    'e3 f3',
  ], 'd3 c3 b3 a3 f3 e3'),
  RoutePlan(
    'Back of the depot',
    'The next colour is deeper than it looks.',
    ['a3 b3 c3 d3', 'e3', 'f3'],
    'c3 b3 a3 d3 e3 f3',
    hard: true,
  ),
  RoutePlan(
    'Double departure',
    'Prepare two matching routes, then clear them together.',
    ['a3 c3', 'b3 d3', 'e3'],
    'a1 b1 a1 b1 a1 b1 d2 c2 d1 c1 e3',
  ),
  RoutePlan('Garden express', 'A light route before the next lesson.', [
    'a3 b3',
    'c3 d3',
    'e3',
  ], 'c3 a3 e3 b3 d3'),
  RoutePlan(
    'Small or large?',
    'Seat counts matter. Choose the bus that fits the queue.',
    ['a2 b4', 'a4 c2', 'd3'],
    'a4 c2 a2 b4 d3',
  ),
  RoutePlan(
    'The right fit',
    'A large bus can wait for passengers that arrive much later.',
    ['a4 b2', 'a2 c4', 'd3'],
    'a2 c4 a4 b2 d3',
  ),
  RoutePlan(
    'Two sizes',
    'Compare seats before committing a parking space.',
    ['a2 b4 c2', 'a4 d2', 'e4'],
    'a4 d2 b4 a2 c2 e4',
    hard: true,
  ),
  RoutePlan('Little shuttle', 'A short bus can free a place earlier.', [
    'a2 b2',
    'c4 d2',
    'c2',
  ], 'c2 a2 b2 c4 d2'),
  RoutePlan('Coastal breeze', 'Keep the departures moving.', [
    'a2 b4',
    'c2 d4',
    'e2',
  ], 'a2 c2 e2 b4 d4'),
  RoutePlan(
    'Last passenger',
    'Partly filled buses stay. Check the next group too.',
    ['a4 b2', 'c2 a2', 'd4 e2'],
    'a2 c2 b2 a4 d4 e2',
  ),
  RoutePlan(
    'Deep blue',
    'Free the hidden bus without filling the terminal.',
    ['a2 b4 c2', 'd4 e2', 'f2'],
    'c2 b4 a2 e2 d4 f2',
    hard: true,
  ),
  RoutePlan(
    'Shared route',
    'Two buses of one colour do not always have the same job.',
    ['a2 b4', 'a4 c2', 'd4 e2'],
    'a4 c2 d4 a2 b4 e2',
  ),
  RoutePlan(
    'Terminal pressure',
    'Reserve room for the final link in the chain.',
    ['a2 b4 c2', 'd2 e4', 'f4'],
    'c1 b2 a1 c1 b2 a1 e4 d2 f4',
    hard: true,
  ),
  RoutePlan('Evening cruise', 'Clear one group at a time.', [
    'a4 b2',
    'c4 d2',
    'e2 f2',
  ], 'c4 a4 e2 b2 d2 f2'),
  RoutePlan(
    'Three-way junction',
    'The first useful bus is not necessarily the first useful move.',
    ['a2 b4', 'c4 d2', 'e2 f4'],
    'b4 a2 d1 c2 d1 c2 f4 e2',
  ),
  RoutePlan(
    'Large buses, small spaces',
    'Match the group size while leaving an exit open.',
    ['a6 b2', 'a2 c4', 'd2 e4'],
    'a2 c4 a6 b2 e4 d2',
    hard: true,
  ),
  RoutePlan('City connections', 'Follow the queue through both exits.', [
    'a2 b4 c2',
    'd4 e2',
    'f2 a4',
  ], 'e2 d4 c2 b4 a2 f2 a4'),
  RoutePlan(
    'Perfect dispatch',
    'Look ahead before sending a bus for a future group.',
    ['a4 b2 c4', 'a2 d4', 'e2 f4'],
    'a2 d4 c2 b1 a2 c2 b1 a2 f4 e2',
    hard: true,
  ),
  RoutePlan(
    'Depot master',
    'Combine blocked exits, mixed groups and different seat counts.',
    ['a2 b4 c2', 'd4 e2', 'a4 f2'],
    'c1 b2 a1 c1 b2 a1 a4 f2 e2 d4',
    hard: true,
  ),
];
