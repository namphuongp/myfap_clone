import { clean } from "../../../utils/serialize.js";
import { activityLogRepository } from "../../../repositories/index.js";
// Ghi nhật ký thao tác cùng dữ liệu trước và sau.
export async function audit(
  session,
  user,
  action,
  entity,
  key,
  before = null,
  after = null,
  requestId = null,
) {
  await activityLogRepository.create(
    [
      {
        actor_id: user._id,
        action,
        entity,
        entity_id: key,
        request_id: requestId,
        before_data: clean(before),
        after_data: clean(after),
      },
    ],
    { session },
  );
}
