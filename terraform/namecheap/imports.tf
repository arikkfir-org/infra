# Every domain was registered, and its nameservers set, at Namecheap by hand first.
import {
  for_each = local.domains

  to = namecheap_domain_records.this[each.key]
  id = each.key
}
