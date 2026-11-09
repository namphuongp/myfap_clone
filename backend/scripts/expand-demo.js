const baseUrl = `http://127.0.0.1:${process.env.PORT ?? 3000}/api`;
const password = process.env.SEED_PASSWORD;

if (!password) throw new Error("Cần SEED_PASSWORD trong backend/.env");

async function request(method, path, token, data) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(data ? { "Content-Type": "application/json" } : {}),
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
  });
  if (response.status === 204) return null;
  const result = await response.json();
  if (!response.ok)
    throw new Error(`${method} ${path}: ${result.message ?? response.status}`);
  return result;
}

const mondayInVietnam = () => {
  const local = new Date(Date.now() + 7 * 3600000);
  const today = new Date(
    Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()),
  );
  return new Date(today.getTime() - ((today.getUTCDay() + 6) % 7) * 86400000);
};

const dateOf = (monday, week, weekday) =>
  new Date(monday.getTime() + (week * 7 + weekday) * 86400000)
    .toISOString()
    .slice(0, 10);

const slotStart = (date, slot) =>
  new Date(
    `${date}T${["07:30", "10:00", "12:50", "15:20"][slot - 1]}:00+07:00`,
  );

async function main() {
  const staff = await request("POST", "/auth/login", null, {
    email: "staff@myfap.local",
    password,
  });
  let student;
  try {
    student = await request("POST", "/auth/login", null, {
      email: "student@myfap.local",
      password,
    });
    const token = staff.accessToken;
    const [departments, semesters, rooms, courses, sections] =
      await Promise.all([
        request("GET", "/departments", token),
        request("GET", "/semesters", token),
        request("GET", "/rooms", token),
        request("GET", "/courses", token),
        request("GET", "/sections", token),
      ]);
    const department = departments.find((row) => row.code === "SE");
    const semester = semesters.find((row) => row.code.startsWith("DEMO-"));
    const room301 = rooms.find((row) => row.name === "BE-301");
    const room302 = rooms.find((row) => row.name === "BE-302");
    const existingSection = sections.find((row) => row.code === "SE20A-PRM393");
    if (!department || !semester || !room301 || !room302 || !existingSection)
      throw new Error("Database cần dữ liệu demo từ npm run seed trước");

    const stats = { courses: 0, sections: 0, sessions: 0, enrollments: 0 };
    const specs = [
      {
        courseCode: "PRM393",
        sectionCode: "SE20A-PRM393",
        room: room301,
        meetingTimes: [
          [0, 1],
          [2, 1],
        ],
        enroll: false,
      },
      {
        courseCode: "DBI202",
        courseName: "Cơ sở dữ liệu",
        sectionCode: "SE20A-DBI202",
        room: room301,
        meetingTimes: [
          [2, 2],
          [4, 2],
        ],
        enroll: true,
      },
      {
        courseCode: "SWP391",
        courseName: "Dự án phần mềm",
        sectionCode: "SE20A-SWP391",
        room: room302,
        meetingTimes: [
          [3, 1],
          [4, 3],
        ],
        enroll: true,
      },
      {
        courseCode: "WDP301",
        courseName: "Phát triển ứng dụng web",
        sectionCode: "SE20B-WDP301",
        room: room302,
        meetingTimes: [
          [3, 3],
          [5, 1],
        ],
        enroll: false,
      },
    ];

    const monday = mondayInVietnam();
    const sectionsToEnroll = [];
    for (const spec of specs) {
      let course = courses.find((row) => row.code === spec.courseCode);
      if (!course) {
        course = await request("POST", "/courses", token, {
          code: spec.courseCode,
          name: spec.courseName,
          department_id: department.id,
        });
        courses.push(course);
        stats.courses++;
      }
      let section = sections.find(
        (row) =>
          row.code === spec.sectionCode && row.semester_id === semester.id,
      );
      if (!section) {
        section = await request("POST", "/sections", token, {
          code: spec.sectionCode,
          course_id: course.id,
          semester_id: semester.id,
          lecturer_id: existingSection.lecturer_id,
        });
        sections.push(section);
        stats.sections++;
      }

      const sessions = await request(
        "GET",
        `/sections/${section.id}/sessions`,
        token,
      );
      for (let week = 0; week < 3; week++) {
        for (const [weekday, slot] of spec.meetingTimes) {
          const date = dateOf(monday, week, weekday);
          if (slotStart(date, slot) <= new Date()) continue;
          if (
            sessions.some(
              (row) => row.session_date === date && row.slot_id === slot,
            )
          )
            continue;
          const session = await request("POST", "/sessions", token, {
            section_id: section.id,
            room_id: spec.room.id,
            session_date: date,
            slot_id: slot,
          });
          sessions.push(session);
          stats.sessions++;
        }
      }
      if (spec.enroll) sectionsToEnroll.push(section);
    }

    const enrollments = await request(
      "GET",
      "/me/enrollments",
      student.accessToken,
    );
    for (const section of sectionsToEnroll) {
      if (
        enrollments.some(
          (row) => row.section_id === section.id && row.status === "ACTIVE",
        )
      )
        continue;
      await request("POST", `/sections/${section.id}/enrollments`, token, {
        student_id: student.user.id,
      });
      stats.enrollments++;
    }

    console.log(
      `Đã thêm ${stats.courses} môn, ${stats.sections} lớp, ${stats.sessions} buổi, ${stats.enrollments} đăng ký.`,
    );
  } finally {
    await Promise.allSettled([
      request("POST", "/auth/logout", staff.accessToken),
      ...(student
        ? [request("POST", "/auth/logout", student.accessToken)]
        : []),
    ]);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
