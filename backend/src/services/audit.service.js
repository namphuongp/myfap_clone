import { clean } from "../utils/serialize.js";
import { auditRepository } from "../repositories/index.js";
export async function audit(
  session,
  user,
  action,
  entity,
  key,
  before = null,
  after = null,
) {
  await auditRepository.create(
    [
      {
        actor_id: user._id,
        action,
        entity,
        entity_id: key,
        before_data: clean(before),
        after_data: clean(after),
      },
    ],
    { session },
  );
}
