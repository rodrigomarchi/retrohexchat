/**
 * A FreeCell table built by hand: the columns, cells and foundations given,
 * every other column `fill()` (empty unless said), cell and foundation empty.
 */
export function table({ columns = [], cells = [], foundations = [] } = {}, fill = () => []) {
  return {
    columns: Array.from({ length: 8 }, (_, i) => columns[i] ?? fill()),
    cells: Array.from({ length: 4 }, (_, i) => cells[i] ?? null),
    foundations: Array.from({ length: 4 }, (_, i) => foundations[i] ?? []),
  };
}
