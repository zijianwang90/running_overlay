# Security Policy

## Supported Versions

Security fixes are applied to the latest protected release-ready branch.
Pre-release builds may change without backward compatibility guarantees.

## Reporting

Do not publish an unpatched vulnerability, credential, private FIT file, GPS
trace, or source video in a public issue.

Use GitHub's private vulnerability reporting feature for this repository. If
that feature is unavailable, contact the repository owner privately through
the contact method listed on the GitHub profile.

Include:

- affected version or commit;
- reproduction steps or a minimal proof of concept;
- impact assessment;
- suggested mitigation, if known.

The project will acknowledge a valid report, investigate it, and coordinate a
fix and disclosure timeline. No fixed response-time SLA is currently offered.

## Sensitive Data

Running Overlay processes activity timestamps, GPS traces, local media paths,
and optional API credentials. Test cases and issue reports must use synthetic
or intentionally public data. OpenWeather keys and signing credentials must
never be committed.
