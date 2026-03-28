import m1Data from './datasets/m1.json';
import m2Data from './datasets/m2.json';
import math12Data from './datasets/12th-math.json';
import phy1Data from './datasets/phy1.json';
import phy2Data from './datasets/phy2.json';
import phy12Data from './datasets/12th-phy.json';
import chem1Data from './datasets/chem1.json';
import chem2Data from './datasets/chem2.json';
import beeData from './datasets/eng-bee.json';
import preBeeData from './datasets/pre-bee.json';
import mechData from './datasets/eng-mech.json';
import preMechData from './datasets/pre-eng-mech.json';
import egData from './datasets/eng-graphics.json';
import cpData from './datasets/cp.json';
import dbmsData from './datasets/dbms.json';
import mpData from './datasets/mp.json';
import osData from './datasets/os.json';

export interface Question {
  id: string;
  type: string;
  difficulty: string;
  concept: string;
  question: string;
  options?: string[];
  answer: string;
  explanation: string;
}

export interface Subject {
  id: string;
  name: string;
  shortName: string;
  color: string;
  icon: string;
  prerequisiteId?: string;
  questions: Question[];
}

export const subjects: Subject[] = [
  { id: '12th_math', name: '12th Mathematics (Complex Numbers)', shortName: '12th Math', color: '#a78bfa', icon: '📐', questions: math12Data.questions as Question[] },
  { id: 'math1', name: 'Engineering Mathematics 1', shortName: 'Math I', color: '#8b5cf6', icon: '∑', questions: m1Data.questions as Question[], prerequisiteId: '12th_math' },
  { id: 'm2', name: 'Engineering Mathematics 2', shortName: 'Math II', color: '#ec4899', icon: '∫', questions: m2Data.questions as Question[], prerequisiteId: 'math1' },
  
  { id: '12th_phy', name: '12th Physics (Dual Nature)', shortName: '12th Physics', color: '#fbbf24', icon: '🔬', questions: phy12Data.questions as Question[] },
  { id: 'phy1', name: 'Engineering Physics 1', shortName: 'Physics', color: '#f59e0b', icon: '⚛', questions: phy1Data.questions as Question[], prerequisiteId: '12th_phy' },
  { id: 'phy2', name: 'Engineering Physics 2', shortName: 'Physics II', color: '#f97316', icon: '🧲', questions: phy2Data.questions as Question[], prerequisiteId: 'phy1' },
  
  { id: 'chem1', name: 'Engineering Chemistry 1', shortName: 'Chemistry', color: '#10b981', icon: '⚗', questions: chem1Data.questions as Question[] },
  { id: 'chem2', name: 'Engineering Chemistry 2', shortName: 'Chemistry II', color: '#14b8a6', icon: '🧪', questions: chem2Data.questions as Question[], prerequisiteId: 'chem1' },
  
  { id: 'pre_bee', name: 'BEE Prerequisites', shortName: 'Pre-BEE', color: '#f87171', icon: '🔌', questions: preBeeData.questions as Question[] },
  { id: 'bee', name: 'Basic Electrical Engineering', shortName: 'Electrical', color: '#ef4444', icon: '⚡', questions: beeData.questions as Question[], prerequisiteId: 'pre_bee' },
  
  { id: 'pre_mech', name: 'Mechanics Prerequisites', shortName: 'Pre-Mech', color: '#22d3ee', icon: '📏', questions: preMechData.questions as Question[] },
  { id: 'mech', name: 'Engineering Mechanics', shortName: 'Mechanics', color: '#06b6d4', icon: '⚙', questions: mechData.questions as Question[], prerequisiteId: 'pre_mech' },
  
  { id: 'eg', name: 'Engineering Graphics', shortName: 'Graphics', color: '#3b82f6', icon: '📐', questions: egData.questions as Question[] },
  { id: 'cp', name: 'Computer Programming', shortName: 'Programming', color: '#eab308', icon: '💻', questions: cpData.questions as Question[] },
  
  { id: 'dbms', name: 'Database Management Systems', shortName: 'DBMS', color: '#f43f5e', icon: '🗄️', questions: dbmsData.questions as Question[] },
  { id: 'os', name: 'Operating Systems', shortName: 'OS', color: '#0ea5e9', icon: '🖥️', questions: osData.questions as Question[] },
  { id: 'mp', name: 'Microprocessors', shortName: 'MP', color: '#10b981', icon: '🔌', questions: mpData.questions as Question[] },
];

// Only show main engineering subjects (not prerequisite subjects) on quiz selection
export const mainSubjects = subjects.filter(s => !s.id.startsWith('12th_') && !s.id.startsWith('pre_'));

export const getSubject = (id: string) => subjects.find(s => s.id === id);

export const getPrerequisite = (id: string) => {
  const subj = getSubject(id);
  return subj?.prerequisiteId ? getSubject(subj.prerequisiteId) : null;
};
