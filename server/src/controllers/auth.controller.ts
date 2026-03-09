import { Request, Response } from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import prisma from '../lib/prisma'

export async function register(req: Request, res: Response): Promise<void> {
  try {
    const { email, name, password } = req.body
    const existing = await prisma.user.findUnique({ where: { email } })
    if (existing) {
      res.status(400).json({ error: 'Email already in use' })
      return
    }
    const hashed = await bcrypt.hash(password, 10)

    // Create team + user + default project in one transaction
    const result = await prisma.$transaction(async (tx) => {
      const team = await tx.team.create({ data: { name: `${name}'s Team` } })
      const user = await tx.user.create({
        data: { email, name, password: hashed, teamId: team.id },
        select: { id: true, email: true, name: true, role: true },
      })
      const project = await tx.project.create({
        data: { teamId: team.id, name: 'Default Project', description: 'My first project' },
      })
      return { user, project }
    })

    const token = jwt.sign(
      { userId: result.user.id, role: result.user.role },
      process.env.JWT_SECRET!,
      { expiresIn: '7d' }
    )
    res.status(201).json({ user: result.user, token, defaultProjectId: result.project.id })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Registration failed' })
  }
}

export async function login(req: Request, res: Response): Promise<void> {
  try {
    const { email, password } = req.body
    const user = await prisma.user.findUnique({ where: { email } })
    if (!user || !(await bcrypt.compare(password, user.password))) {
      res.status(401).json({ error: 'Invalid credentials' })
      return
    }

    // Fetch user's default project
    const project = await prisma.project.findFirst({
      where: { team: { users: { some: { id: user.id } } } },
      orderBy: { createdAt: 'asc' },
    })

    const token = jwt.sign(
      { userId: user.id, role: user.role },
      process.env.JWT_SECRET!,
      { expiresIn: '7d' }
    )
    res.json({
      user: { id: user.id, email: user.email, name: user.name, role: user.role },
      token,
      defaultProjectId: project?.id ?? null,
    })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Login failed' })
  }
}

export async function me(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).userId
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true, role: true },
    })
    const project = await prisma.project.findFirst({
      where: { team: { users: { some: { id: userId } } } },
      orderBy: { createdAt: 'asc' },
    })
    res.json({ ...user, defaultProjectId: project?.id ?? null })
  } catch {
    res.status(500).json({ error: 'Failed to fetch user' })
  }
}